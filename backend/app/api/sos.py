"""
Tourist Safety Backend — SOS API

Receives distress payloads from the mobile app.
"""

from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.database import get_db
from app.models.db_models import DistressIncident, IncidentStatus, TriggerType, User
from app.models.schemas import DistressPayloadRequest, DistressIncidentResponse
from app.api.auth import get_current_user

router = APIRouter(prefix="/sos", tags=["SOS / Emergency"])


@router.post("/trigger", response_model=DistressIncidentResponse, status_code=status.HTTP_201_CREATED)
async def trigger_sos(
    payload: DistressPayloadRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Receive a distress payload from the mobile app.

    This is the primary entry point for all emergency triggers:
    - Manual SOS button press
    - Passive audio detection (scream/impact)
    - Passive kinetic detection (fall/struggle)
    - Duress PIN activation
    """
    incident = DistressIncident(
        user_id=user.id,
        trigger_type=TriggerType(payload.trigger_type),
        status=IncidentStatus.ACTIVE,
        latitude=payload.latitude,
        longitude=payload.longitude,
        altitude=payload.altitude,
        accuracy=payload.accuracy,
        battery_level=payload.battery_level,
        metadata_json=payload.metadata,
        encrypted_payload=payload.encrypted_payload,
    )
    db.add(incident)
    await db.flush()

    # TODO: Trigger real-time notification to dashboard via WebSocket/Redis pub-sub
    # TODO: Send push notification to emergency contacts

    return DistressIncidentResponse(
        id=str(incident.id),
        user_id=str(incident.user_id),
        user_name=user.name,
        trigger_type=incident.trigger_type.value,
        status=incident.status.value,
        latitude=incident.latitude,
        longitude=incident.longitude,
        altitude=incident.altitude,
        accuracy=incident.accuracy,
        battery_level=incident.battery_level,
        metadata_json=incident.metadata_json,
        created_at=incident.created_at,
        resolved_at=incident.resolved_at,
    )


@router.post("/{incident_id}/resolve")
async def resolve_sos(
    incident_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Mark an SOS incident as resolved (cancelled by user or responder)."""
    result = await db.execute(
        select(DistressIncident).where(
            DistressIncident.id == incident_id,
            DistressIncident.user_id == user.id,
        )
    )
    incident = result.scalar_one_or_none()
    if not incident:
        raise HTTPException(status_code=404, detail="Incident not found")

    if incident.status == IncidentStatus.RESOLVED:
        raise HTTPException(status_code=400, detail="Incident already resolved")

    incident.status = IncidentStatus.RESOLVED
    incident.resolved_at = datetime.utcnow()
    await db.flush()

    return {"status": "resolved", "incident_id": incident_id}


@router.get("/active", response_model=list[DistressIncidentResponse])
async def get_active_incidents(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get all active SOS incidents for the current user."""
    result = await db.execute(
        select(DistressIncident).where(
            DistressIncident.user_id == user.id,
            DistressIncident.status == IncidentStatus.ACTIVE,
        ).order_by(DistressIncident.created_at.desc())
    )
    incidents = result.scalars().all()

    return [
        DistressIncidentResponse(
            id=str(inc.id),
            user_id=str(inc.user_id),
            user_name=user.name,
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
        for inc in incidents
    ]
