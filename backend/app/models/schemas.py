"""
Tourist Safety Backend — Pydantic Schemas

Request/response schemas for API validation.
"""

import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, EmailStr, Field


# ─── Auth Schemas ─────────────────────────────────────────────

class UserRegisterRequest(BaseModel):
    email: str = Field(..., max_length=255)
    password: str = Field(..., min_length=8, max_length=128)
    name: str = Field(..., min_length=1, max_length=255)
    phone: Optional[str] = None


class UserLoginRequest(BaseModel):
    email: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user_id: str


class UserResponse(BaseModel):
    id: str
    email: str
    name: str
    phone: Optional[str] = None
    is_admin: bool = False
    created_at: datetime

    class Config:
        from_attributes = True


# ─── SOS / Distress Schemas ──────────────────────────────────

class DistressPayloadRequest(BaseModel):
    """Incoming distress payload from the mobile app."""
    payload_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    trigger_type: str = Field(..., pattern="^(manual|passive_audio|passive_kinetic|duress)$")
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    altitude: Optional[float] = None
    accuracy: Optional[float] = None
    battery_level: Optional[int] = Field(None, ge=0, le=100)
    metadata: dict = Field(default_factory=dict)
    encrypted_payload: Optional[str] = None


class DistressIncidentResponse(BaseModel):
    """Distress incident as returned by the API."""
    id: str
    user_id: str
    user_name: str = ""
    trigger_type: str
    status: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    altitude: Optional[float] = None
    accuracy: Optional[float] = None
    battery_level: Optional[int] = None
    metadata_json: dict = Field(default_factory=dict)
    created_at: datetime
    resolved_at: Optional[datetime] = None

    class Config:
        from_attributes = True


# ─── Location Schemas ────────────────────────────────────────

class LocationUpdate(BaseModel):
    """A single GPS breadcrumb from the mobile app."""
    latitude: float
    longitude: float
    altitude: Optional[float] = None
    accuracy: Optional[float] = None
    speed: Optional[float] = None
    heading: Optional[float] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class LocationLogResponse(BaseModel):
    id: str
    user_id: str
    latitude: float
    longitude: float
    altitude: Optional[float] = None
    accuracy: Optional[float] = None
    speed: Optional[float] = None
    heading: Optional[float] = None
    timestamp: datetime

    class Config:
        from_attributes = True


# ─── Dashboard Schemas ───────────────────────────────────────

class DashboardStats(BaseModel):
    """Summary stats for the admin dashboard."""
    active_incidents: int
    total_incidents_today: int
    total_users: int
    online_users: int


class DispatchRequest(BaseModel):
    """Admin dispatches a responder to an incident."""
    incident_id: str
    responder_notes: Optional[str] = None


# ─── Red Zone Schemas ────────────────────────────────────────

class RedZoneResponse(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    latitude: float
    longitude: float
    radius_meters: float
    severity: str
    source_headline: Optional[str] = None
    active: bool
    expires_at: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True
