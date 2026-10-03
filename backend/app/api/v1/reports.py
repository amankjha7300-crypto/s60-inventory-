from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy.orm import Session
from sqlalchemy import desc
from typing import Optional, List
import csv
import io

from app.database.session import get_db
from app.models.all_models import (
    Event, Student, EventInventory, Distribution, AcademicSession, Admin, InventoryItem
)
from app.schemas.schemas import ApiResponse
from app.api.deps import get_current_admin

router = APIRouter(prefix="/reports", tags=["Reports & Analytics"])

@router.get("/events", response_model=ApiResponse)
def get_event_reports(
    status: Optional[str] = Query(None),
    scheme: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    query = db.query(Event)
    if status and status.upper() != "ALL":
        query = query.filter(Event.status.ilike(status.strip()))
    if scheme and scheme.upper() != "ALL":
        query = query.filter(Event.semester_scheme == scheme.upper())

    events = query.order_by(desc(Event.id)).all()
    results = []
    for ev in events:
        total_qty = sum(i.initial_quantity for i in ev.event_inventories)
        dist_qty = sum(i.distributed_quantity for i in ev.event_inventories)
        rem_qty = sum(i.remaining_quantity for i in ev.event_inventories)
        items_count = len(ev.event_inventories)

        results.append({
            "event_id": ev.id,
            "event_uid": ev.event_uid,
            "event_name": ev.name,
            "event_type": ev.event_type,
            "event_date": ev.event_date,
            "status": ev.status,
            "scheme": ev.semester_scheme,
            "participants_count": len(ev.participants),
            "items_count": items_count,
            "total_quantity": total_qty,
            "distributed_quantity": dist_qty,
            "remaining_quantity": rem_qty,
            "completion_percentage": round((dist_qty / total_qty * 100), 1) if total_qty > 0 else 0
        })

    return ApiResponse(success=True, data=results)

@router.get("/inventory", response_model=ApiResponse)
def get_inventory_reports(
    event_id: Optional[int] = Query(None),
    category: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    query = db.query(EventInventory)
    if event_id:
        query = query.filter(EventInventory.event_id == event_id)

    records = query.all()
    results = []
    for r in records:
        item = r.inventory_item
        ev = r.event
        if category and item and item.category.lower() != category.lower():
            continue

        status_str = "Available"
        if r.remaining_quantity <= 0:
            status_str = "Out of Stock"
        elif r.remaining_quantity <= r.low_stock_threshold:
            status_str = "Low Stock"

        results.append({
            "id": r.id,
            "item_name": item.name if item else "Item",
            "category": item.category if item else "Other",
            "unit": item.unit if item else "units",
            "event_name": ev.name if ev else "Event",
            "event_uid": ev.event_uid if ev else "",
            "initial_quantity": r.initial_quantity,
            "distributed_quantity": r.distributed_quantity,
            "remaining_quantity": r.remaining_quantity,
            "eligibility_type": r.eligibility_type,
            "status": status_str
        })

    return ApiResponse(success=True, data=results)

@router.get("/distribution", response_model=ApiResponse)
def get_distribution_reports(
    event_id: Optional[int] = Query(None),
    semester: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    query = db.query(Distribution).filter(Distribution.status == "DISTRIBUTED")
    if event_id:
        query = query.filter(Distribution.event_id == event_id)
    if semester:
        query = query.filter(Distribution.semester_at_distribution == semester)

    dists = query.order_by(desc(Distribution.distributed_at)).all()
    results = []
    for d in dists:
        ev = d.event
        st = d.student
        inv = d.event_inventory.inventory_item if d.event_inventory else None
        results.append({
            "distribution_id": d.id,
            "event_name": ev.name if ev else "Event",
            "student_id": st.student_id if st else "",
            "student_name": st.name if st else "",
            "student_roll": st.roll_number if st else "",
            "item_name": inv.name if inv else "Item",
            "quantity": d.quantity,
            "semester_at_distribution": d.semester_at_distribution,
            "session_at_distribution": d.session_at_distribution,
            "distributed_at": d.distributed_at.strftime("%d %b %Y, %I:%M %p"),
            "distributed_by": d.distributed_by_name
        })

    return ApiResponse(success=True, data=results)

@router.get("/students", response_model=ApiResponse)
def get_student_reward_reports(
    semester: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    query = db.query(Student).filter(Student.status == "ACTIVE")
    if semester:
        query = query.filter(Student.current_semester == semester)

    students = query.order_by(Student.student_id.asc()).all()
    results = []
    for st in students:
        dists = db.query(Distribution).filter(Distribution.student_id == st.id, Distribution.status == "DISTRIBUTED").all()
        events_count = len(set(d.event_id for d in dists))
        total_items = sum(d.quantity for d in dists)

        results.append({
            "student_id": st.student_id,
            "roll_number": st.roll_number,
            "name": st.name,
            "semester": st.current_semester,
            "events_attended": events_count,
            "rewards_received": total_items
        })

    return ApiResponse(success=True, data=results)

@router.get("/export-csv")
def export_csv(
    report_type: str = Query("distribution", description="distribution, events, inventory, students"),
    event_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    """
    Exports clean, human-readable CSV report files.
    """
    output = io.StringIO()
    writer = csv.writer(output)

    if report_type == "distribution":
        filename = "S60_Distribution_Report.csv"
        writer.writerow(["Student ID", "Roll Number", "Student Name", "Event", "Item", "Quantity", "Semester", "Session", "Distributed At", "Distributed By"])
        query = db.query(Distribution).filter(Distribution.status == "DISTRIBUTED")
        if event_id:
            query = query.filter(Distribution.event_id == event_id)
        for d in query.order_by(desc(Distribution.distributed_at)).all():
            ev = d.event
            st = d.student
            inv = d.event_inventory.inventory_item if d.event_inventory else None
            writer.writerow([
                st.student_id if st else "",
                st.roll_number if st else "",
                st.name if st else "",
                ev.name if ev else "",
                inv.name if inv else "",
                d.quantity,
                f"Sem {d.semester_at_distribution}",
                d.session_at_distribution,
                d.distributed_at.strftime("%d-%m-%Y %H:%M"),
                d.distributed_by_name
            ])

    elif report_type == "events":
        filename = "S60_Events_Report.csv"
        writer.writerow(["Event UID", "Event Name", "Type", "Date", "Status", "Scheme", "Total Items", "Distributed", "Remaining", "Completion %"])
        for ev in db.query(Event).order_by(desc(Event.id)).all():
            total_qty = sum(i.initial_quantity for i in ev.event_inventories)
            dist_qty = sum(i.distributed_quantity for i in ev.event_inventories)
            rem_qty = sum(i.remaining_quantity for i in ev.event_inventories)
            pct = round((dist_qty / total_qty * 100), 1) if total_qty > 0 else 0
            writer.writerow([
                ev.event_uid, ev.name, ev.event_type, ev.event_date, ev.status, ev.semester_scheme,
                total_qty, dist_qty, rem_qty, f"{pct}%"
            ])

    elif report_type == "inventory":
        filename = "S60_Inventory_Report.csv"
        writer.writerow(["Item Name", "Category", "Event", "Initial Quantity", "Distributed", "Remaining", "Status"])
        for r in db.query(EventInventory).all():
            item = r.inventory_item
            ev = r.event
            status_str = "Available" if r.remaining_quantity > r.low_stock_threshold else ("Out of Stock" if r.remaining_quantity <= 0 else "Low Stock")
            writer.writerow([
                item.name if item else "", item.category if item else "", ev.name if ev else "",
                r.initial_quantity, r.distributed_quantity, r.remaining_quantity, status_str
            ])

    else:
        filename = "S60_Students_Report.csv"
        writer.writerow(["Student ID", "Roll Number", "Name", "Semester", "Rewards Received"])
        for st in db.query(Student).filter(Student.status == "ACTIVE").order_by(Student.student_id.asc()).all():
            dists = db.query(Distribution).filter(Distribution.student_id == st.id, Distribution.status == "DISTRIBUTED").all()
            total_items = sum(d.quantity for d in dists)
            writer.writerow([st.student_id, st.roll_number, st.name, st.current_semester, total_items])

    output.seek(0)
    return Response(
        content=output.getvalue(),
        media_type="text/csv",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'}
    )
