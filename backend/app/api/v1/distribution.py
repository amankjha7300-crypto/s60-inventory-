from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from sqlalchemy import desc, and_
from typing import Optional, List, Dict, Any
import datetime

from app.database.session import get_db
from app.models.all_models import (
    Distribution, Event, Student, EventInventory, InventoryItem,
    Winner, AcademicSession, AuditLog, Admin
)
from app.schemas.schemas import (
    ApiResponse, DistributionRecordResponse, BatchDistributionRequest,
    DistributionSaveItem, DistributionRemarkRequest
)
from app.api.deps import get_current_admin

router = APIRouter(prefix="/distribution", tags=["Rewards & Distribution"])

def utcnow():
    return datetime.datetime.now(datetime.timezone.utc)

@router.get("/event/{event_id}/matrix", response_model=ApiResponse)
def get_event_distribution_matrix(
    event_id: int,
    semester: Optional[int] = Query(None),
    status_filter: Optional[str] = Query(None, description="ALL, COMPLETED, PARTIAL, PENDING"),
    search: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    """
    Returns student-by-inventory distribution grid/cards for the event.
    Calculates who is eligible for each item (ALL, SEMESTER, WINNERS, SELECTED)
    and checks if it has already been received.
    """
    event = db.query(Event).filter(Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found.")

    event_inventories = db.query(EventInventory).filter(EventInventory.event_id == event_id).all()
    winners = db.query(Winner).filter(Winner.event_id == event_id).all()
    winner_map = {w.student_id: w.position for w in winners}

    # Applicable semesters
    sem_list = [int(x.strip()) for x in event.applicable_semesters.split(",") if x.strip().isdigit()]

    # Query students
    st_query = db.query(Student).filter(Student.status == "ACTIVE")
    if semester:
        st_query = st_query.filter(Student.current_semester == semester)
    elif not search:
        st_query = st_query.filter(Student.current_semester.in_(sem_list))

    if search:
        s = f"%{search.strip()}%"
        st_query = st_query.filter(
            (Student.name.ilike(s)) | (Student.student_id.ilike(s)) | (Student.roll_number.ilike(s))
        )

    students = st_query.order_by(Student.id.asc()).all()

    # Query all existing distributions for this event (DISTRIBUTED, PENDING_REMARK, CANCELLED)
    all_dists = db.query(Distribution).filter(
        Distribution.event_id == event_id
    ).order_by(Distribution.id.asc()).all()

    # Map (student_id, event_inventory_id) -> Distribution, prioritizing DISTRIBUTED
    dist_map = {}
    for d in all_dists:
        prev = dist_map.get((d.student_id, d.event_inventory_id))
        if not prev or d.status == "DISTRIBUTED" or prev.status != "DISTRIBUTED":
            dist_map[(d.student_id, d.event_inventory_id)] = d

    matrix_rows = []
    summary_received_total = 0
    summary_eligible_total = 0
    summary_remarked_total = 0

    for st in students:
        is_winner = st.id in winner_map
        winner_pos = winner_map.get(st.id)

        items_status = {}
        student_eligible_count = 0
        student_received_count = 0

        for inv in event_inventories:
            item_name = inv.inventory_item.name if inv.inventory_item else "Item"
            # Determine eligibility
            eligible = False
            if inv.eligibility_type == "ALL":
                eligible = True
            elif inv.eligibility_type == "SEMESTER":
                eligible = (inv.semester_filter is None or st.current_semester == inv.semester_filter)
            elif inv.eligibility_type == "WINNERS":
                eligible = is_winner
            elif inv.eligibility_type == "SELECTED":
                eligible = True

            dist_rec = dist_map.get((st.id, inv.id))
            received = (dist_rec is not None and dist_rec.status == "DISTRIBUTED")
            remarks_text = (dist_rec.remarks or "").strip() if dist_rec else ""
            has_remark = bool(remarks_text)

            if eligible:
                student_eligible_count += 1
                if received:
                    student_received_count += 1
                elif has_remark:
                    summary_remarked_total += 1

            items_status[inv.id] = {
                "inventory_item_id": inv.inventory_item_id,
                "item_name": item_name,
                "category": inv.inventory_item.category if inv.inventory_item else "",
                "eligible": eligible,
                "received": received,
                "quantity": dist_rec.quantity if (dist_rec and received) else 0,
                "distribution_id": dist_rec.id if (dist_rec and received) else None,
                "distributed_at": dist_rec.distributed_at.isoformat() if (dist_rec and received) else None,
                "remaining_stock": inv.remaining_quantity,
                "remarks": remarks_text,
                "has_remark": has_remark
            }

        # Determine row status
        if student_eligible_count == 0:
            row_status = "NOT_ELIGIBLE"
        elif student_received_count == student_eligible_count:
            row_status = "COMPLETED"
        elif student_received_count > 0:
            row_status = "PARTIAL"
        else:
            row_status = "PENDING"

        if status_filter and status_filter.upper() != "ALL":
            if row_status != status_filter.upper():
                continue

        summary_received_total += student_received_count
        summary_eligible_total += student_eligible_count

        matrix_rows.append({
            "student_id": st.id,
            "student_uid": st.student_id,
            "name": st.name,
            "roll_number": st.roll_number,
            "semester": st.current_semester,
            "is_winner": is_winner,
            "winner_position": winner_pos,
            "items": items_status,
            "total_eligible": student_eligible_count,
            "total_received": student_received_count,
            "status": row_status
        })

    # Calculate global completion readiness across ALL active students for this event
    all_applicable_students = db.query(Student).filter(
        Student.status == "ACTIVE",
        Student.current_semester.in_(sem_list)
    ).all()

    global_eligible_count = 0
    global_distributed_count = 0
    global_remarked_count = 0
    unaccounted_list = []

    for st in all_applicable_students:
        is_win = st.id in winner_map
        for inv in event_inventories:
            el = False
            if inv.eligibility_type == "ALL":
                el = True
            elif inv.eligibility_type == "SEMESTER":
                el = (inv.semester_filter is None or st.current_semester == inv.semester_filter)
            elif inv.eligibility_type == "WINNERS":
                el = is_win
            elif inv.eligibility_type == "SELECTED":
                el = True

            if not el:
                continue

            global_eligible_count += 1
            rec = dist_map.get((st.id, inv.id))
            is_dist = (rec is not None and rec.status == "DISTRIBUTED")
            has_rem = (rec is not None and bool((rec.remarks or "").strip()))

            if is_dist:
                global_distributed_count += 1
            elif has_rem:
                global_remarked_count += 1
            else:
                item_name = inv.inventory_item.name if inv.inventory_item else "Item"
                unaccounted_list.append(f"{st.name} ({st.roll_number}) - {item_name}")

    unaccounted_count = len(unaccounted_list)
    can_complete = (unaccounted_count == 0)

    # Inventory headers
    inventory_columns = [
        {
            "id": inv.id,
            "item_name": inv.inventory_item.name if inv.inventory_item else "Item",
            "category": inv.inventory_item.category if inv.inventory_item else "",
            "initial_quantity": inv.initial_quantity,
            "distributed_quantity": inv.distributed_quantity,
            "remaining_quantity": inv.remaining_quantity,
            "eligibility_type": inv.eligibility_type
        }
        for inv in event_inventories
    ]

    return ApiResponse(
        success=True,
        data={
            "event_id": event.id,
            "event_uid": event.event_uid,
            "event_name": event.name,
            "event_status": event.status,
            "event_date": event.event_date,
            "inventory_columns": inventory_columns,
            "rows": matrix_rows,
            "total_students": len(matrix_rows),
            "summary": {
                "total_eligible_items": summary_eligible_total,
                "total_distributed_items": summary_received_total,
                "total_remarked_items": summary_remarked_total,
                "completion_rate": round(summary_received_total / summary_eligible_total * 100, 1) if summary_eligible_total > 0 else 0,
                "global_eligible_items": global_eligible_count,
                "global_distributed_items": global_distributed_count,
                "global_remarked_items": global_remarked_count,
                "can_complete": can_complete,
                "unaccounted_count": unaccounted_count,
                "unaccounted_sample": unaccounted_list[:5]
            }
        }
    )

@router.post("/save", response_model=ApiResponse)
def record_distribution(
    item_data: DistributionSaveItem,
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    """
    CRITICAL REQUIREMENT: Records reward distribution atomically in management database.
    Does NOT send any student notifications or trigger student apps.
    Validates stock availability, avoids duplicates, and takes semester snapshot.
    """
    student = db.query(Student).filter(Student.id == item_data.student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found.")

    ev_inv = db.query(EventInventory).filter(EventInventory.id == item_data.event_inventory_id).with_for_update().first()
    if not ev_inv:
        raise HTTPException(status_code=404, detail="Event inventory item not found.")

    item_name = ev_inv.inventory_item.name if ev_inv.inventory_item else "Item"

    # Duplicate check: check if already distributed
    existing = db.query(Distribution).filter(
        Distribution.event_id == ev_inv.event_id,
        Distribution.student_id == student.id,
        Distribution.event_inventory_id == ev_inv.id
    ).order_by(Distribution.id.desc()).first()

    if existing and existing.status == "DISTRIBUTED":
        raise HTTPException(
            status_code=400,
            detail=f"{student.name} has already received '{item_name}' for this event."
        )

    # Quantity check
    qty = item_data.quantity or 1
    if qty <= 0:
        raise HTTPException(status_code=400, detail="Distribution quantity must be at least 1.")

    if ev_inv.remaining_quantity < qty:
        raise HTTPException(
            status_code=400,
            detail=f"Insufficient inventory! Only {ev_inv.remaining_quantity} units of '{item_name}' are currently available (requested: {qty})."
        )

    # Academic session snapshot
    ev = ev_inv.event
    session_name = ev.academic_session.session_name if (ev and ev.academic_session) else "2026-27"

    # Create or update Distribution record
    if existing:
        dist = existing
        dist.quantity = qty
        dist.status = "DISTRIBUTED"
        dist.distributed_at = utcnow()
        dist.distributed_by_id = admin.id
        dist.distributed_by_name = admin.full_name
        dist.semester_at_distribution = student.current_semester
        dist.session_at_distribution = session_name
        if item_data.remarks is not None:
            dist.remarks = item_data.remarks
    else:
        dist = Distribution(
            event_id=ev_inv.event_id,
            student_id=student.id,
            event_inventory_id=ev_inv.id,
            quantity=qty,
            status="DISTRIBUTED",
            distributed_at=utcnow(),
            distributed_by_id=admin.id,
            distributed_by_name=admin.full_name,
            semester_at_distribution=student.current_semester,  # Immutable historical snapshot
            session_at_distribution=session_name,
            remarks=item_data.remarks
        )
        db.add(dist)

    # Atomically decrement remaining and increment distributed
    ev_inv.distributed_quantity += qty
    ev_inv.remaining_quantity -= qty

    # Audit log
    audit = AuditLog(
        admin_id=admin.id,
        admin_name=admin.full_name,
        action="DISTRIBUTE_REWARD",
        entity_type="Distribution",
        entity_id=f"{student.student_id}:{item_name}",
        new_data=f"Distributed {qty}x {item_name} to {student.name} ({student.student_id}). Remaining stock: {ev_inv.remaining_quantity}"
    )
    db.add(audit)

    db.commit()
    db.refresh(dist)
    db.refresh(ev_inv)

    return ApiResponse(
        success=True,
        data={
            "distribution_id": dist.id,
            "student_name": student.name,
            "item_name": item_name,
            "quantity": dist.quantity,
            "remaining_quantity": ev_inv.remaining_quantity,
            "status": "DISTRIBUTED"
        },
        message=f"Reward recorded successfully: {student.name} received {qty}x {item_name}."
    )

@router.post("/batch", response_model=ApiResponse)
def record_batch_distributions(
    batch: BatchDistributionRequest,
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    """
    Save multiple distributions at once in a single atomic database transaction.
    """
    event = db.query(Event).filter(Event.id == batch.event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found.")

    session_name = event.academic_session.session_name if event.academic_session else "2026-27"
    saved_count = 0
    errors = []

    for item in batch.distributions:
        student = db.query(Student).filter(Student.id == item.student_id).first()
        ev_inv = db.query(EventInventory).filter(EventInventory.id == item.event_inventory_id).with_for_update().first()
        if not student or not ev_inv:
            errors.append("Invalid student or inventory ID")
            continue

        item_name = ev_inv.inventory_item.name if ev_inv.inventory_item else "Item"

        # Check duplicate
        existing = db.query(Distribution).filter(
            Distribution.event_id == event.id,
            Distribution.student_id == student.id,
            Distribution.event_inventory_id == ev_inv.id,
            Distribution.status == "DISTRIBUTED"
        ).first()

        if existing:
            continue  # Already distributed, skip without breaking batch

        qty = item.quantity or 1
        if ev_inv.remaining_quantity < qty:
            errors.append(f"Insufficient stock for {item_name} ({ev_inv.remaining_quantity} left)")
            continue

        dist = Distribution(
            event_id=event.id,
            student_id=student.id,
            event_inventory_id=ev_inv.id,
            quantity=qty,
            status="DISTRIBUTED",
            distributed_at=utcnow(),
            distributed_by_id=admin.id,
            distributed_by_name=admin.full_name,
            semester_at_distribution=student.current_semester,
            session_at_distribution=session_name,
            remarks=item.remarks
        )
        db.add(dist)
        ev_inv.distributed_quantity += qty
        ev_inv.remaining_quantity -= qty
        saved_count += 1

    db.commit()

    return ApiResponse(
        success=True,
        data={"saved_count": saved_count, "errors": errors},
        message=f"{saved_count} reward distributions saved successfully."
    )

@router.post("/{distribution_id}/reverse", response_model=ApiResponse)
def reverse_distribution(
    distribution_id: int,
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    """
    Explicit Undo Distribution: Returns distributed unit back to inventory
    and updates audit log.
    """
    dist = db.query(Distribution).filter(Distribution.id == distribution_id).first()
    if not dist:
        raise HTTPException(status_code=404, detail="Distribution record not found.")

    if dist.status != "DISTRIBUTED":
        raise HTTPException(status_code=400, detail="This distribution is not active.")

    ev_inv = db.query(EventInventory).filter(EventInventory.id == dist.event_inventory_id).with_for_update().first()
    student = dist.student
    item_name = ev_inv.inventory_item.name if (ev_inv and ev_inv.inventory_item) else "Item"

    # Return quantity to inventory
    if ev_inv:
        ev_inv.distributed_quantity -= dist.quantity
        ev_inv.remaining_quantity += dist.quantity

    dist.status = "CANCELLED"

    audit = AuditLog(
        admin_id=admin.id,
        admin_name=admin.full_name,
        action="UNDO_DISTRIBUTION",
        entity_type="Distribution",
        entity_id=str(dist.id),
        old_data=f"Distributed {dist.quantity}x {item_name} to {student.name if student else 'Student'}",
        new_data=f"Reversed by {admin.full_name}. Restored stock to {ev_inv.remaining_quantity if ev_inv else 'N/A'}"
    )
    db.add(audit)
    db.commit()

    return ApiResponse(
        success=True,
        data={
            "distribution_id": dist.id,
            "status": "CANCELLED",
            "restored_remaining_stock": ev_inv.remaining_quantity if ev_inv else 0
        },
        message=f"Distribution reversed. {dist.quantity} unit returned to inventory."
    )

@router.post("/remark", response_model=ApiResponse)
def update_distribution_remark(
    data: DistributionRemarkRequest,
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    """
    CRITICAL REQUIREMENT:
    Records or updates a remark for an unreceived / pending inventory item for a student.
    Does not decrement inventory stock.
    Required for event completion when item is not distributed.
    """
    event = db.query(Event).filter(Event.id == data.event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found.")

    student = db.query(Student).filter(Student.id == data.student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found.")

    ev_inv = db.query(EventInventory).filter(EventInventory.id == data.event_inventory_id).first()
    if not ev_inv:
        raise HTTPException(status_code=404, detail="Event inventory item not found.")

    item_name = ev_inv.inventory_item.name if ev_inv.inventory_item else "Item"
    remarks_clean = data.remarks.strip() if data.remarks else ""

    # Check existing distribution record
    dist = db.query(Distribution).filter(
        Distribution.event_id == data.event_id,
        Distribution.student_id == data.student_id,
        Distribution.event_inventory_id == data.event_inventory_id
    ).order_by(Distribution.id.desc()).first()

    session_name = event.academic_session.session_name if event.academic_session else "2026-27"

    if dist:
        dist.remarks = remarks_clean if remarks_clean else None
        if dist.status != "DISTRIBUTED":
            dist.status = "PENDING_REMARK" if remarks_clean else "CANCELLED"
            dist.quantity = 0
            dist.distributed_by_id = admin.id
            dist.distributed_by_name = admin.full_name
            dist.updated_at = utcnow()
    else:
        dist = Distribution(
            event_id=event.id,
            student_id=student.id,
            event_inventory_id=ev_inv.id,
            quantity=0,
            status="PENDING_REMARK" if remarks_clean else "PENDING",
            distributed_at=utcnow(),
            distributed_by_id=admin.id,
            distributed_by_name=admin.full_name,
            semester_at_distribution=student.current_semester,
            session_at_distribution=session_name,
            remarks=remarks_clean if remarks_clean else None
        )
        db.add(dist)

    audit = AuditLog(
        admin_id=admin.id,
        admin_name=admin.full_name,
        action="UPDATE_DISTRIBUTION_REMARK",
        entity_type="Distribution",
        entity_id=f"{student.student_id}:{item_name}",
        new_data=f"Updated remark for {student.name} ({student.student_id}) on {item_name}: '{remarks_clean}'"
    )
    db.add(audit)
    db.commit()

    return ApiResponse(
        success=True,
        message=f"Remark for {student.name} updated successfully.",
        data={
            "student_id": student.id,
            "student_name": student.name,
            "event_inventory_id": ev_inv.id,
            "remarks": remarks_clean,
            "has_remark": bool(remarks_clean)
        }
    )

@router.get("/history", response_model=ApiResponse)
def list_distribution_history(
    event_id: Optional[int] = Query(None),
    student_id: Optional[int] = Query(None),
    semester: Optional[int] = Query(None),
    status: Optional[str] = Query("DISTRIBUTED"),
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    query = db.query(Distribution)
    if event_id:
        query = query.filter(Distribution.event_id == event_id)
    if student_id:
        query = query.filter(Distribution.student_id == student_id)
    if semester:
        query = query.filter(Distribution.semester_at_distribution == semester)
    if status and status.upper() != "ALL":
        query = query.filter(Distribution.status == status.upper())

    total = query.count()
    records = query.order_by(desc(Distribution.distributed_at)).offset((page - 1) * page_size).limit(page_size).all()

    items = []
    for d in records:
        ev = d.event
        st = d.student
        ev_inv = d.event_inventory
        inv_item = ev_inv.inventory_item if ev_inv else None

        items.append({
            "id": d.id,
            "event_id": d.event_id,
            "event_name": ev.name if ev else "Event",
            "student_id": d.student_id,
            "student_uid": st.student_id if st else "",
            "student_name": st.name if st else "",
            "student_roll": st.roll_number if st else "",
            "inventory_item_id": inv_item.id if inv_item else 0,
            "item_name": inv_item.name if inv_item else "Item",
            "quantity": d.quantity,
            "status": d.status,
            "distributed_at": d.distributed_at.isoformat(),
            "distributed_by_name": d.distributed_by_name,
            "semester_at_distribution": d.semester_at_distribution,
            "session_at_distribution": d.session_at_distribution,
            "remarks": d.remarks
        })

    return ApiResponse(
        success=True,
        data={
            "items": items,
            "total": total,
            "page": page,
            "page_size": page_size
        }
    )
