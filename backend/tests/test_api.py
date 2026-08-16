"""
Tourist Safety Backend — Test Suite

Tests for auth, SOS, and dashboard API endpoints.
"""

import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport

from app.main import app
from app.db.database import init_db, engine, Base


@pytest_asyncio.fixture(autouse=True)
async def setup_db():
    """Create tables before each test, drop after."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest_asyncio.fixture
async def client():
    """Async test client for the FastAPI app."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest_asyncio.fixture
async def auth_headers(client: AsyncClient):
    """Register a test user and return auth headers."""
    resp = await client.post("/api/v1/auth/register", json={
        "email": "test@tourist.com",
        "password": "TestPass123!",
        "name": "Test Tourist",
    })
    assert resp.status_code == 201
    token = resp.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


# ─── Auth Tests ──────────────────────────────────────────────

@pytest.mark.asyncio
async def test_register_success(client: AsyncClient):
    resp = await client.post("/api/v1/auth/register", json={
        "email": "new@tourist.com",
        "password": "SecurePass1!",
        "name": "New Tourist",
    })
    assert resp.status_code == 201
    data = resp.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["token_type"] == "bearer"


@pytest.mark.asyncio
async def test_register_duplicate_email(client: AsyncClient):
    # First registration
    await client.post("/api/v1/auth/register", json={
        "email": "dupe@tourist.com",
        "password": "SecurePass1!",
        "name": "Tourist 1",
    })
    # Second with same email
    resp = await client.post("/api/v1/auth/register", json={
        "email": "dupe@tourist.com",
        "password": "AnotherPass1!",
        "name": "Tourist 2",
    })
    assert resp.status_code == 409


@pytest.mark.asyncio
async def test_login_success(client: AsyncClient):
    # Register first
    await client.post("/api/v1/auth/register", json={
        "email": "login@tourist.com",
        "password": "LoginPass1!",
        "name": "Login Tourist",
    })
    # Login
    resp = await client.post("/api/v1/auth/login", json={
        "email": "login@tourist.com",
        "password": "LoginPass1!",
    })
    assert resp.status_code == 200
    assert "access_token" in resp.json()


@pytest.mark.asyncio
async def test_login_wrong_password(client: AsyncClient):
    await client.post("/api/v1/auth/register", json={
        "email": "wrong@tourist.com",
        "password": "CorrectPass1!",
        "name": "Wrong Tourist",
    })
    resp = await client.post("/api/v1/auth/login", json={
        "email": "wrong@tourist.com",
        "password": "WrongPass1!",
    })
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_get_me(client: AsyncClient, auth_headers: dict):
    resp = await client.get("/api/v1/auth/me", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["email"] == "test@tourist.com"
    assert data["name"] == "Test Tourist"


# ─── SOS Tests ───────────────────────────────────────────────

@pytest.mark.asyncio
async def test_trigger_sos(client: AsyncClient, auth_headers: dict):
    resp = await client.post("/api/v1/sos/trigger", headers=auth_headers, json={
        "trigger_type": "manual",
        "latitude": 28.6139,
        "longitude": 77.2090,
        "battery_level": 75,
    })
    assert resp.status_code == 201
    data = resp.json()
    assert data["trigger_type"] == "manual"
    assert data["status"] == "active"
    assert data["latitude"] == 28.6139


@pytest.mark.asyncio
async def test_trigger_sos_without_location(client: AsyncClient, auth_headers: dict):
    """SOS should work even without GPS (permission denied scenario)."""
    resp = await client.post("/api/v1/sos/trigger", headers=auth_headers, json={
        "trigger_type": "manual",
    })
    assert resp.status_code == 201
    assert resp.json()["latitude"] is None


@pytest.mark.asyncio
async def test_resolve_sos(client: AsyncClient, auth_headers: dict):
    # Trigger SOS first
    trigger_resp = await client.post("/api/v1/sos/trigger", headers=auth_headers, json={
        "trigger_type": "manual",
        "latitude": 28.6139,
        "longitude": 77.2090,
    })
    incident_id = trigger_resp.json()["id"]

    # Resolve it
    resp = await client.post(f"/api/v1/sos/{incident_id}/resolve", headers=auth_headers)
    assert resp.status_code == 200
    assert resp.json()["status"] == "resolved"


@pytest.mark.asyncio
async def test_get_active_incidents(client: AsyncClient, auth_headers: dict):
    # Trigger two SOS events
    await client.post("/api/v1/sos/trigger", headers=auth_headers, json={"trigger_type": "manual"})
    await client.post("/api/v1/sos/trigger", headers=auth_headers, json={"trigger_type": "passive_audio"})

    resp = await client.get("/api/v1/sos/active", headers=auth_headers)
    assert resp.status_code == 200
    assert len(resp.json()) == 2


# ─── Health Check Tests ──────────────────────────────────────

@pytest.mark.asyncio
async def test_health(client: AsyncClient):
    resp = await client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "healthy"


@pytest.mark.asyncio
async def test_root(client: AsyncClient):
    resp = await client.get("/")
    assert resp.status_code == 200
    assert resp.json()["status"] == "running"
