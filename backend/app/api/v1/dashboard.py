from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import desc, func
from typing import Dict, Any

from app.database.session import get_db
from app.models.all_models import (
    Event, Student, EventInventory, Distribution, AcademicSession, Admin, InventoryItem
)
from app.schemas.schemas import ApiResponse
from app.api.deps import get_current_admin

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])

@router.get("", response_model=ApiResponse)
def get_dashboard_overview(
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    """
    Returns live aggregated dashboard metrics calculated directly from database records.
    """
    # Active Session & Scheme
    session = db.query(AcademicSession).filter(AcademicSession.is_active == True).order_by(AcademicSession.id.desc()).first()
    session_name = session.session_name if session else "2026-27"
    scheme = session.current_scheme if session else "ODD"
    active_semesters = [3, 5, 7] if scheme == "ODD" else [4, 6, 8]

    # Students count
    active_students_count = db.query(Student).filter(Student.status == "ACTIVE").count()

    # Events count
    total_events_count = db.query(Event).count()
    active_events_count = db.query(Event).filter(Event.status.in_(["Upcoming", "Active", "Ongoing"])).count()
    completed_events_count = db.query(Event).filter(Event.status == "Completed").count()

    # Inventory totals
    all_ev_inv = db.query(EventInventory).all()
    total_inventory_units = sum(i.initial_quantity for i in all_ev_inv)
    total_distributed_units = sum(i.distributed_quantity for i in all_ev_inv)
    total_pending_units = total_inventory_units - total_distributed_units

    # Low Stock Alerts
    low_stock_alerts = []
    for inv in all_ev_inv:
        if inv.remaining_quantity <= inv.low_stock_threshold:
            item_name = inv.inventory_item.name if inv.inventory_item else "Item"
            ev_name = inv.event.name if inv.event else "Event"
            low_stock_alerts.append({
                "event_inventory_id": inv.id,
                "item_name": item_name,
                "event_name": ev_name,
                "remaining": inv.remaining_quantity,
                "threshold": inv.low_stock_threshold,
                "status": "Out of Stock" if inv.remaining_quantity <= 0 else "Low Stock"
            })

    # Recent Events (Top 5)
    recent_events_db = db.query(Event).order_by(desc(Event.id)).limit(5).all()
    recent_events = []
    for ev in recent_events_db:
        total_qty = sum(i.initial_quantity for i in ev.event_inventories)
        dist_qty = sum(i.distributed_quantity for i in ev.event_inventories)
        rem_qty = sum(i.remaining_quantity for i in ev.event_inventories)
        pct = round((dist_qty / total_qty * 100), 1) if total_qty > 0 else 0.0

        recent_events.append({
            "id": ev.id,
            "event_uid": ev.event_uid,
            "name": ev.name,
            "event_type": ev.event_type,
            "event_date": ev.event_date,
            "status": ev.status,
            "semester_scheme": ev.semester_scheme,
            "total_participants": len(ev.participants),
            "total_quantity": total_qty,
            "distributed_quantity": dist_qty,
            "remaining_quantity": rem_qty,
            "distribution_percentage": pct
        })

    # Recent Distributions (Top 6)
    recent_dists_db = db.query(Distribution).filter(Distribution.status == "DISTRIBUTED").order_by(desc(Distribution.distributed_at)).limit(6).all()
    recent_distributions = []
    for d in recent_dists_db:
        st = d.student
        ev = d.event
        inv = d.event_inventory.inventory_item if d.event_inventory else None
        recent_distributions.append({
            "id": d.id,
            "student_name": st.name if st else "Student",
            "student_uid": st.student_id if st else "",
            "event_name": ev.name if ev else "Event",
            "item_name": inv.name if inv else "Item",
            "quantity": d.quantity,
            "distributed_at": d.distributed_at.isoformat(),
            "distributed_by_name": d.distributed_by_name
        })

    return ApiResponse(
        success=True,
        data={
            "academic_session_name": session_name,
            "current_scheme": scheme,
            "active_semesters": active_semesters,
            "active_students_count": active_students_count,
            "active_events_count": active_events_count,
            "completed_events_count": completed_events_count,
            "total_events_count": total_events_count,
            "total_inventory_units": total_inventory_units,
            "total_distributed_units": total_distributed_units,
            "total_pending_units": total_pending_units,
            "recent_events": recent_events,
            "low_stock_alerts": low_stock_alerts[:8],
            "recent_distributions": recent_distributions
        }
    )
