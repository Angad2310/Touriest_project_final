"""
Tourist Safety Backend — Database Models

SQLAlchemy ORM models for PostgreSQL.
"""

import uuid
from datetime import datetime
from enum import Enum as PyEnum

from sqlalchemy import (
    Column, String, Float, DateTime, Enum, Boolean,
    Text, Integer, ForeignKey, Index,
)
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship

from app.db.database import Base


class TriggerType(str, PyEnum):
    """How the emergency was triggered."""
    MANUAL = "manual"
    PASSIVE_AUDIO = "passive_audio"
    PASSIVE_KINETIC = "passive_kinetic"
    DURESS = "duress"


class IncidentStatus(str, PyEnum):
    """Lifecycle status of a distress incident."""
    ACTIVE = "active"
    DISPATCHED = "dispatched"
    RESOLVED = "resolved"
    CANCELLED = "cancelled"


class User(Base):
    """Registered app user."""
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String(255), unique=True, nullable=False, index=True)
    name = Column(String(255), nullable=False)
    password_hash = Column(String(255), nullable=False)
    phone = Column(String(50), nullable=True)
    emergency_contacts = Column(JSONB, default=list)
    is_admin = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    incidents = relationship("DistressIncident", back_populates="user", lazy="selectin")
    location_logs = relationship("LocationLog", back_populates="user", lazy="selectin")


class DistressIncident(Base):
    """A single emergency event — from trigger to resolution."""
    __tablename__ = "distress_incidents"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    trigger_type = Column(Enum(TriggerType), nullable=False)
    status = Column(Enum(IncidentStatus), default=IncidentStatus.ACTIVE, nullable=False)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    altitude = Column(Float, nullable=True)
    accuracy = Column(Float, nullable=True)
    battery_level = Column(Integer, nullable=True)
    metadata_json = Column(JSONB, default=dict)
    encrypted_payload = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, index=True)
    resolved_at = Column(DateTime, nullable=True)

    # Relationships
    user = relationship("User", back_populates="incidents")

    __table_args__ = (
        Index("idx_incidents_status_created", "status", "created_at"),
    )


class LocationLog(Base):
    """GPS breadcrumb trail for a user — used for live tracking replay."""
    __tablename__ = "location_logs"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    incident_id = Column(UUID(as_uuid=True), ForeignKey("distress_incidents.id"), nullable=True, index=True)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    altitude = Column(Float, nullable=True)
    accuracy = Column(Float, nullable=True)
    speed = Column(Float, nullable=True)
    heading = Column(Float, nullable=True)
    timestamp = Column(DateTime, default=datetime.utcnow, index=True)

    # Relationships
    user = relationship("User", back_populates="location_logs")

    __table_args__ = (
        Index("idx_location_user_time", "user_id", "timestamp"),
    )


class RedZone(Base):
    """A geographic danger zone identified by the threat intelligence NLP pipeline."""
    __tablename__ = "red_zones"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    radius_meters = Column(Float, nullable=False, default=500.0)
    severity = Column(String(50), nullable=False, default="medium")  # low, medium, high, critical
    source_url = Column(Text, nullable=True)
    source_headline = Column(Text, nullable=True)
    active = Column(Boolean, default=True)
    expires_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        Index("idx_redzones_active_location", "active", "latitude", "longitude"),
    )
