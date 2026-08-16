"""
Tourist Safety Backend — Location Tracking API

WebSocket endpoint for real-time GPS streaming from mobile app.
HTTP endpoint for batch location log storage.
"""

from datetime import datetime

from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.database import get_db, async_session_factory
from app.models.db_models import LocationLog, User
from app.models.schemas import LocationUpdate, LocationLogResponse
from app.api.auth import get_current_user

router = APIRouter(prefix="/tracking", tags=["Location Tracking"])


# ─── Active WebSocket connections (in-memory for MVP; Redis pub-sub for scale)
_active_connections: dict[str, WebSocket] = {}


def get_active_connections() -> dict[str, WebSocket]:
    """Returns dict of user_id → WebSocket for dashboard to fan out."""
    return _active_connections


@router.websocket("/ws/{user_id}")
async def location_websocket(websocket: WebSocket, user_id: str):
    """
    WebSocket endpoint for live location streaming.

    The mobile app connects here during active tracking/SOS and sends
    LocationUpdate JSON messages. The dashboard can read from _active_connections
    to fan out location updates to admin viewers.
    """
    await websocket.accept()
    _active_connections[user_id] = websocket

    try:
        while True:
            data = await websocket.receive_json()
            loc = LocationUpdate(**data)

            # Persist to database
            async with async_session_factory() as db:
                log = LocationLog(
                    user_id=user_id,
                    latitude=loc.latitude,
                    longitude=loc.longitude,
                    altitude=loc.altitude,
                    accuracy=loc.accuracy,
                    speed=loc.speed,
                    heading=loc.heading,
                    timestamp=loc.timestamp,
                )
                db.add(log)
                await db.commit()

            # Echo back acknowledgment
            await websocket.send_json({"status": "received", "timestamp": loc.timestamp.isoformat()})

    except WebSocketDisconnect:
        _active_connections.pop(user_id, None)
    except Exception:
        _active_connections.pop(user_id, None)


@router.post("/batch")
async def batch_location_update(
    locations: list[LocationUpdate],
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Batch upload location logs (used when flushing offline-queued positions).
    """
    if len(locations) > 500:
        raise HTTPException(status_code=400, detail="Maximum 500 locations per batch")

    for loc in locations:
        log = LocationLog(
            user_id=user.id,
            latitude=loc.latitude,
            longitude=loc.longitude,
            altitude=loc.altitude,
            accuracy=loc.accuracy,
            speed=loc.speed,
            heading=loc.heading,
            timestamp=loc.timestamp,
        )
        db.add(log)

    await db.flush()

    return {"status": "ok", "count": len(locations)}
