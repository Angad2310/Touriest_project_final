"""
Tourist Safety Backend — Dashboard API

Admin-facing endpoints for viewing incidents, dispatching responders, and stats.
"""

from datetime import datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.database import get_db
from app.models.db_models import (
    DistressIncident, IncidentStatus, User, LocationLog, RedZone,
)
from app.models.schemas import (
    DistressIncidentResponse, DashboardStats, DispatchRequest,
    LocationLogResponse, RedZoneResponse,
)
from app.api.auth import get_admin_user, get_current_user

router = APIRouter(prefix="/dashboard", tags=["Admin Dashboard"])


@router.get("/stats", response_model=DashboardStats)
async def get_dashboard_stats(
    admin: User = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
):
    """Get summary statistics for the dashboard overview."""
    today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)

    # Active incidents
    active_result = await db.execute(
        select(func.count()).select_from(DistressIncident).where(
            DistressIncident.status == IncidentStatus.ACTIVE,
        )
    )
    active_count = active_result.scalar() or 0

    # Today's total incidents
    today_result = await db.execute(
        select(func.count()).select_from(DistressIncident).where(
            DistressIncident.created_at >= today_start,
        )
    )
    today_count = today_result.scalar() or 0

    # Total users
    users_result = await db.execute(select(func.count()).select_from(User))
    total_users = users_result.scalar() or 0

    return DashboardStats(
        active_incidents=active_count,
        total_incidents_today=today_count,
        total_users=total_users,
        online_users=0,  # TODO: Track via WebSocket connections
    )


@router.get("/active-alerts", response_model=list[DistressIncidentResponse])
async def get_active_alerts(
    admin: User = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
):
    """Get all currently active distress incidents across all users."""
    result = await db.execute(
        select(DistressIncident, User.name).join(
            User, DistressIncident.user_id == User.id
        ).where(
            DistressIncident.status.in_([
                IncidentStatus.ACTIVE,
                IncidentStatus.DISPATCHED,
            ])
        ).order_by(DistressIncident.created_at.desc())
    )
    rows = result.all()

    return [
        DistressIncidentResponse(
            id=str(inc.id),
            user_id=str(inc.user_id),
            user_name=name,
            trigger_type=inc.trigger_type.value,
            status=inc.status.value,
            latitude=inc.latitude,
            longitude=inc.longitude,
            altitude=inc.altitude,
            accuracy=inc.accuracy,
            battery_level=inc.battery_level,
            metadata_json=inc.metadata_json,
            created_at=inc.created_at,
            resolved_at=inc.resolved_at,
        )
        for inc, name in rows
    ]


@router.get("/incidents", response_model=list[DistressIncidentResponse])
async def get_incident_history(
    admin: User = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    """Get paginated incident history for the dashboard."""
    offset = (page - 1) * page_size

    result = await db.execute(
        select(DistressIncident, User.name).join(
            User, DistressIncident.user_id == User.id
        ).order_by(
            DistressIncident.created_at.desc()
        ).offset(offset).limit(page_size)
    )
    rows = result.all()

    return [
        DistressIncidentResponse(
            id=str(inc.id),
            user_id=str(inc.user_id),
            user_name=name,
            trigger_type=inc.trigger_type.value,
            status=inc.status.value,
            latitude=inc.latitude,
            longitude=inc.longitude,
            altitude=inc.altitude,
            accuracy=inc.accuracy,
            battery_level=inc.battery_level,
            metadata_json=inc.metadata_json,
            created_at=inc.created_at,
            resolved_at=inc.resolved_at,
        )
        for inc, name in rows
    ]


@router.post("/dispatch")
async def dispatch_responder(
    req: DispatchRequest,
    admin: User = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
):
    """Dispatch a responder to an active incident."""
    result = await db.execute(
        select(DistressIncident).where(DistressIncident.id == req.incident_id)
    )
    incident = result.scalar_one_or_none()
    if not incident:
        raise HTTPException(status_code=404, detail="Incident not found")

    if incident.status != IncidentStatus.ACTIVE:
        raise HTTPException(status_code=400, detail=f"Cannot dispatch to {incident.status.value} incident")

    incident.status = IncidentStatus.DISPATCHED
    if req.responder_notes:
        incident.metadata_json = {
            **(incident.metadata_json or {}),
            "dispatch_notes": req.responder_notes,
            "dispatched_at": datetime.utcnow().isoformat(),
            "dispatched_by": str(admin.id),
        }
    await db.flush()

    return {"status": "dispatched", "incident_id": req.incident_id}


@router.get("/location-history/{user_id}", response_model=list[LocationLogResponse])
async def get_location_history(
    user_id: str,
    admin: User = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
    limit: int = Query(100, ge=1, le=1000),
):
    """Get recent location breadcrumbs for a user (for replay on dashboard map)."""
    result = await db.execute(
        select(LocationLog).where(
            LocationLog.user_id == user_id
        ).order_by(
            LocationLog.timestamp.desc()
        ).limit(limit)
    )
    logs = result.scalars().all()

    return [
        LocationLogResponse(
            id=str(log.id),
            user_id=str(log.user_id),
            latitude=log.latitude,
            longitude=log.longitude,
            altitude=log.altitude,
            accuracy=log.accuracy,
            speed=log.speed,
            heading=log.heading,
            timestamp=log.timestamp,
        )
        for log in logs
    ]


# ─── Red Zones (public, no admin required) ──────────────────

redzones_router = APIRouter(prefix="/threats", tags=["Threat Intelligence"])


@redzones_router.get("/red-zones", response_model=list[RedZoneResponse])
async def get_red_zones(
    lat: float = Query(..., description="Center latitude"),
    lng: float = Query(..., description="Center longitude"),
    radius_km: float = Query(50.0, description="Search radius in km"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get active red zones near a location. Used by the mobile app map."""
    # Simple bounding-box filter (good enough for MVP; PostGIS for production)
    # 1 degree latitude ≈ 111 km
    lat_delta = radius_km / 111.0
    lng_delta = radius_km / (111.0 * max(0.01, abs(__import__("math").cos(__import__("math").radians(lat)))))

    result = await db.execute(
        select(RedZone).where(
            RedZone.active == True,
            RedZone.latitude.between(lat - lat_delta, lat + lat_delta),
            RedZone.longitude.between(lng - lng_delta, lng + lng_delta),
        ).order_by(RedZone.severity.desc())
    )
    zones = result.scalars().all()

    return [
        RedZoneResponse(
            id=str(z.id),
            name=z.name,
            description=z.description,
            latitude=z.latitude,
            longitude=z.longitude,
            radius_meters=z.radius_meters,
            severity=z.severity,
            source_headline=z.source_headline,
            active=z.active,
            expires_at=z.expires_at,
            created_at=z.created_at,
        )
        for z in zones
    ]
