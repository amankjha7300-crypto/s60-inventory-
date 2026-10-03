from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse
import os

from app.core.config import settings
from app.database.session import engine, Base
from app.database.seed import seed_database
from app.api.v1 import (
    auth, academic, students, events, inventory, distribution, reports, dashboard, system
)

# Initialize database schema
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="Internal Management System for Super60, Department of Computer Science & Engineering, SVIET.",
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS Configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount Assets Directory if present
assets_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "assets"))
if os.path.exists(assets_path):
    app.mount("/assets", StaticFiles(directory=assets_path), name="assets")

# Mount API Routers under /api/v1
api_v1_prefix = "/api/v1"
app.include_router(auth.router, prefix=api_v1_prefix)
app.include_router(academic.router, prefix=api_v1_prefix)
app.include_router(students.router, prefix=api_v1_prefix)
app.include_router(events.router, prefix=api_v1_prefix)
app.include_router(inventory.router, prefix=api_v1_prefix)
app.include_router(distribution.router, prefix=api_v1_prefix)
app.include_router(reports.router, prefix=api_v1_prefix)
app.include_router(dashboard.router, prefix=api_v1_prefix)
app.include_router(system.router, prefix=api_v1_prefix)


# Mount Web Management Portal if present
web_portal_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "web"))
if os.path.exists(web_portal_path):
    app.mount("/portal", StaticFiles(directory=web_portal_path, html=True), name="portal")

@app.on_event("startup")
def on_startup():
    # Seed default data on startup
    try:
        seed_database(force=False)
    except Exception as e:
        print(f"Startup seed notice: {e}")

@app.get("/health", tags=["System"])
def health_check():
    return {
        "status": "healthy",
        "app": "S60 Inventory & Rewards Management System",
        "version": settings.VERSION,
        "environment": settings.ENVIRONMENT
    }

@app.get("/", tags=["System"])
def root_redirect():
    return {
        "app": "S60 Inventory & Rewards Management System",
        "department": "Super60 / Department of CSE / SVIET",
        "docs": "/docs",
        "api_v1": "/api/v1",
        "portal": "/portal/"
    }
