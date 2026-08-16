"""
Tourist Safety Backend — Main Application Entry Point

FastAPI application with CORS, routers, and startup events.

Run locally:
    uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
"""

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.db.database import init_db
from app.api.auth import router as auth_router
from app.api.sos import router as sos_router
from app.api.tracking import router as tracking_router
from app.api.dashboard import router as dashboard_router, redzones_router

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown events."""
    # Startup: create tables (dev only; use Alembic in production)
    await init_db()
    print(f"🛡️  {settings.app_name} v{settings.app_version} started")
    yield
    # Shutdown
    print("🛡️  Shutting down...")


app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description="Backend API for the Tourist Safety mobile app — emergency response, live tracking, and threat intelligence.",
    lifespan=lifespan,
)

# CORS — allow the dashboard and mobile app to call the API
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount all API routers under /api/v1
app.include_router(auth_router, prefix="/api/v1")
app.include_router(sos_router, prefix="/api/v1")
app.include_router(tracking_router, prefix="/api/v1")
app.include_router(dashboard_router, prefix="/api/v1")
app.include_router(redzones_router, prefix="/api/v1")


@app.get("/", tags=["Health"])
async def root():
    """Health check endpoint."""
    return {
        "service": settings.app_name,
        "version": settings.app_version,
        "status": "running",
    }


@app.get("/health", tags=["Health"])
async def health():
    """Detailed health check."""
    return {
        "status": "healthy",
        "database": "connected",  # TODO: actual DB ping
        "version": settings.app_version,
    }
