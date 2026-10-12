import os
import sys

# Ensure backend directory is in sys.path so 'app' can always be imported
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse, RedirectResponse

from app.core.config import settings
from app.database.session import engine, Base
from app.database.seed import seed_database
from app.api.v1 import (
    auth, academic, students, events, inventory, distribution, reports, dashboard, system
)

# Helper to find resources whether running from source or frozen in PyInstaller
def get_resource_dir(folder_name: str) -> str:
    if hasattr(sys, "_MEIPASS"):
        bundled = os.path.join(sys._MEIPASS, folder_name)
        if os.path.exists(bundled):
            return bundled
    local = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", folder_name))
    if os.path.exists(local):
        return local
    cwd_rel = os.path.abspath(folder_name)
    if os.path.exists(cwd_rel):
        return cwd_rel
    return local

from sqlalchemy import text

# Initialize database schema
Base.metadata.create_all(bind=engine)

def ensure_schema_migrations():
    if not str(engine.url).startswith("sqlite"):
        return
    with engine.connect() as conn:
        try:
            result = conn.execute(text("PRAGMA table_info(inventory_items)")).fetchall()
            col_names = [row[1] for row in result]
            if "initial_stock" not in col_names:
                conn.execute(text("ALTER TABLE inventory_items ADD COLUMN initial_stock INTEGER DEFAULT 0"))
                print("[Migration] Added initial_stock column to inventory_items")
            if "created_source" not in col_names:
                conn.execute(text("ALTER TABLE inventory_items ADD COLUMN created_source VARCHAR(50) DEFAULT 'MASTER'"))
                print("[Migration] Added created_source column to inventory_items")
            if "image_url" not in col_names:
                conn.execute(text("ALTER TABLE inventory_items ADD COLUMN image_url TEXT"))
                print("[Migration] Added image_url column to inventory_items")

            result_ev = conn.execute(text("PRAGMA table_info(event_inventory)")).fetchall()
            col_names_ev = [row[1] for row in result_ev]
            if "image_url" not in col_names_ev:
                conn.execute(text("ALTER TABLE event_inventory ADD COLUMN image_url TEXT"))
                print("[Migration] Added image_url column to event_inventory")

            result_ep = conn.execute(text("PRAGMA table_info(event_participants)")).fetchall()
            col_names_ep = [row[1] for row in result_ep]
            if "remarks" not in col_names_ep:
                conn.execute(text("ALTER TABLE event_participants ADD COLUMN remarks TEXT"))
                print("[Migration] Added remarks column to event_participants")

            result_events = conn.execute(text("PRAGMA table_info(events)")).fetchall()
            col_names_events = [row[1] for row in result_events]
            if "custom_audience" not in col_names_events:
                conn.execute(text("ALTER TABLE events ADD COLUMN custom_audience VARCHAR(200)"))
                print("[Migration] Added custom_audience column to events")
            if "image_url" not in col_names_events:
                conn.execute(text("ALTER TABLE events ADD COLUMN image_url TEXT"))
                print("[Migration] Added image_url column to events")
            
            # Backfill legacy items that were created via events
            conn.execute(text("UPDATE inventory_items SET created_source = 'EVENT' WHERE description LIKE '%event allocation%' OR description LIKE '%Created for event%'"))
            
            # Clean up orphaned event-created items that have no event allocations and no distributions
            conn.execute(text("""
                DELETE FROM inventory_items 
                WHERE (created_source = 'EVENT' OR description LIKE '%event allocation%' OR description LIKE '%Created for event%')
                AND id NOT IN (SELECT DISTINCT inventory_item_id FROM event_inventory)
            """))

            # Sync desynced event items where initial_stock was modified in master catalog
            conn.execute(text("""
                UPDATE event_inventory
                SET initial_quantity = (SELECT initial_stock FROM inventory_items WHERE inventory_items.id = event_inventory.inventory_item_id),
                    remaining_quantity = (SELECT initial_stock FROM inventory_items WHERE inventory_items.id = event_inventory.inventory_item_id) - distributed_quantity
                WHERE inventory_item_id IN (
                    SELECT id FROM inventory_items 
                    WHERE initial_stock > 0 
                    AND (SELECT COUNT(*) FROM event_inventory WHERE inventory_item_id = inventory_items.id) = 1
                )
                AND initial_quantity != (SELECT initial_stock FROM inventory_items WHERE inventory_items.id = event_inventory.inventory_item_id)
                AND (SELECT initial_stock FROM inventory_items WHERE inventory_items.id = event_inventory.inventory_item_id) >= distributed_quantity
            """))
            conn.commit()
        except Exception as e:
            print(f"[Migration Warning] {e}")

ensure_schema_migrations()

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

@app.middleware("http")
async def add_no_cache_headers(request: Request, call_next):
    response = await call_next(request)
    if request.url.path.startswith("/portal") or request.url.path.startswith("/api"):
        response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        response.headers["Pragma"] = "no-cache"
        response.headers["Expires"] = "0"
    return response

# Mount Assets Directory if present
assets_path = get_resource_dir("assets")
if os.path.exists(assets_path):
    app.mount("/assets", StaticFiles(directory=assets_path), name="assets")

# Mount Uploads Directory for uploaded media and assets
uploads_path = get_resource_dir("uploads")
os.makedirs(uploads_path, exist_ok=True)
os.makedirs(os.path.join(uploads_path, "events"), exist_ok=True)
app.mount("/uploads", StaticFiles(directory=uploads_path), name="uploads")

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
web_portal_path = get_resource_dir("web")
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
    return RedirectResponse(url="/portal/")
