from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from sqlalchemy import or_, desc
from typing import Optional, List, Dict, Any
import datetime
import os
import sys
import uuid

from app.database.session import get_db
from app.models.all_models import (
    Event, AcademicSession, InventoryItem, EventInventory,
    EventParticipant, Winner, Distribution, Student, AuditLog, Admin
)
from app.schemas.schemas import (
    ApiResponse, EventCreate, EventUpdate, EventListItemResponse,
    EventDetailResponse, EventInventoryCreate, EventInventoryUpdate,
    WinnerCreate, WinnerResponse
)
from app.api.deps import get_current_admin

router = APIRouter(prefix="/events", tags=["Events & Saved Events"])

def generate_event_uid(db: Session) -> str:
    import re
    existing_uids = [row[0] for row in db.query(Event.event_uid).all() if row[0]]
    max_num = 0
    for uid in existing_uids:
        m = re.search(r"(\d+)$", str(uid))
        if m:
            val = int(m.group(1))
            if val > max_num:
                max_num = val
    next_num = max_num + 1
    candidate = f"S60-EVT-{next_num:04d}"
    while candidate in existing_uids:
        next_num += 1
        candidate = f"S60-EVT-{next_num:04d}"
    return candidate

def compute_stock_status(remaining: int, initial: int, threshold: int) -> str:
    if remaining <= 0:
        return "Out of Stock"
    if remaining <= threshold:
        return "Low Stock"
    return "Available"

@router.get("", response_model=ApiResponse)
def list_saved_events(
    search: Optional[str] = Query(None, description="Search by Event Name, Event UID, Venue"),
    status: Optional[str] = Query(None, description="Upcoming, Ongoing, Active, Completed, Archived, All"),
    event_type: Optional[str] = Query(None),
    scheme: Optional[str] = Query(None, description="ODD or EVEN"),
    semester: Optional[int] = Query(None, description="Applicable semester (3, 4, 5, etc.)"),
    session_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    """
    CRITICAL REQUIREMENT: Saved Events / Event History
    Returns all permanently saved events with search, filters and live distribution statistics.
    """
    query = db.query(Event)

    if status and status.upper() != "ALL":
        if status.capitalize() == "Active":
            query = query.filter(Event.status.in_(["Active", "Ongoing"]))
        else:
            query = query.filter(Event.status.ilike(status.strip()))

    if event_type and event_type.upper() != "ALL":
        query = query.filter(Event.event_type.ilike(event_type.strip()))

    if scheme and scheme.upper() != "ALL":
        query = query.filter(Event.semester_scheme == scheme.upper())

    if session_id:
        query = query.filter(Event.academic_session_id == session_id)

    if search:
        s = f"%{search.strip()}%"
        query = query.filter(
            or_(
                Event.name.ilike(s),
                Event.event_uid.ilike(s),
                Event.venue.ilike(s),
                Event.event_date.ilike(s)
            )
        )

    events = query.order_by(desc(Event.id)).all()

    items = []
    for ev in events:
        # Check semester filter in applicable_semesters
        sem_list = [int(x.strip()) for x in ev.applicable_semesters.split(",") if x.strip().isdigit()]
        if semester and semester not in sem_list:
            continue

        # Aggregated inventory numbers
        inventories = ev.event_inventories
        total_items = len(inventories)
        total_qty = sum(i.initial_quantity for i in inventories)
        distributed_qty = sum(i.distributed_quantity for i in inventories)
        remaining_qty = sum(i.remaining_quantity for i in inventories)
        percentage = round((distributed_qty / total_qty * 100), 1) if total_qty > 0 else 0.0

        participants_count = len(ev.participants)

        items.append({
            "id": ev.id,
            "event_uid": ev.event_uid,
            "name": ev.name,
            "event_type": ev.event_type,
            "event_date": ev.event_date,
            "event_time": ev.event_time,
            "venue": ev.venue,
            "status": ev.status,
            "semester_scheme": ev.semester_scheme,
            "applicable_semesters": sem_list,
            "custom_audience": ev.custom_audience,
            "image_url": ev.image_url,
            "total_participants": participants_count,
            "total_inventory_items": total_items,
            "total_quantity": total_qty,
            "distributed_quantity": distributed_qty,
            "remaining_quantity": remaining_qty,
            "distribution_percentage": percentage
        })

    return ApiResponse(
        success=True,
        data={
            "items": items,
            "total": len(items)
        }
    )

@router.post("", response_model=ApiResponse)
def create_event(
    data: EventCreate,
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    """
    Create a new event and save permanently to database with unique Event UID (e.g. S60-EVT-0001).
    """
    if not data.name.strip():
        raise HTTPException(status_code=400, detail="Event name is required.")

    active_session = db.query(AcademicSession).filter(AcademicSession.is_active == True).first()
    session_id = data.academic_session_id or (active_session.id if active_session else None)
    scheme = data.semester_scheme.upper() if data.semester_scheme else (active_session.current_scheme if active_session else "ODD")

    event_uid = generate_event_uid(db)
    sem_str = ",".join(str(s) for s in data.applicable_semesters) if data.applicable_semesters else ("3,5,7" if scheme == "ODD" else "4,6,8")

    event = Event(
        event_uid=event_uid,
        name=data.name.strip(),
        event_type=data.event_type.strip(),
        description=data.description.strip() if data.description else None,
        event_date=data.event_date.strip(),
        event_time=data.event_time.strip() if data.event_time else None,
        venue=data.venue.strip() if data.venue else None,
        academic_session_id=session_id,
        semester_scheme=scheme,
        applicable_semesters=sem_str,
        custom_audience=data.custom_audience.strip() if data.custom_audience else None,
        image_url=data.image_url.strip() if data.image_url else None,
        status=data.status or "Upcoming",
        created_by_id=admin.id
    )

    committed = False
    for attempt in range(5):
        try:
            event.event_uid = generate_event_uid(db)
            db.add(event)
            db.commit()
            db.refresh(event)
            committed = True
            break
        except Exception as e:
            db.rollback()
            if attempt == 4:
                raise HTTPException(status_code=500, detail=f"Failed to save event: {str(e)}")

    if not committed:
        raise HTTPException(status_code=500, detail="Could not assign unique event UID.")

    # Automatically add eligible students as participants based on applicable semesters
    sem_ints = [int(x) for x in sem_str.split(",") if x.isdigit()]
    eligible_students = db.query(Student).filter(
        Student.status == "ACTIVE",
        Student.current_semester.in_(sem_ints)
    ).all()

    for st in eligible_students:
        part = EventParticipant(event_id=event.id, student_id=st.id, participation_status="ATTENDED")
        db.add(part)

    # If initial items were provided
    if data.initial_items:
        for it in data.initial_items:
            ev_inv = EventInventory(
                event_id=event.id,
                inventory_item_id=it.inventory_item_id,
                initial_quantity=it.initial_quantity,
                distributed_quantity=0,
                remaining_quantity=it.initial_quantity,
                eligibility_type=it.eligibility_type.upper(),
                semester_filter=it.semester_filter,
                low_stock_threshold=it.low_stock_threshold
            )
            db.add(ev_inv)

    audit = AuditLog(
        admin_id=admin.id,
        admin_name=admin.full_name,
        action="CREATE_EVENT",
        entity_type="Event",
        entity_id=event.event_uid,
        new_data=f"Created {event.name} ({event.event_type}) on {event.event_date}"
    )
    db.add(audit)
    db.commit()
    db.refresh(event)

    return ApiResponse(
        success=True,
        data={
            "id": event.id,
            "event_uid": event.event_uid,
            "name": event.name,
            "status": event.status,
            "event_date": event.event_date,
            "semester_scheme": event.semester_scheme,
            "applicable_semesters": sem_ints,
            "participants_added": len(eligible_students)
        },
        message=f"Event '{event.name}' ({event.event_uid}) created and saved successfully."
    )

@router.get("/{event_id}", response_model=ApiResponse)
def get_event_detail(
    event_id: int,
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    event = db.query(Event).filter(Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found.")

    sem_list = [int(x.strip()) for x in event.applicable_semesters.split(",") if x.strip().isdigit()]

    # Inventories list
    inv_list = []
    for inv in event.event_inventories:
        master_item = inv.inventory_item
        status_label = compute_stock_status(inv.remaining_quantity, inv.initial_quantity, inv.low_stock_threshold)
        inv_list.append({
            "id": inv.id,
            "event_id": inv.event_id,
            "inventory_item_id": inv.inventory_item_id,
            "item_name": master_item.name if master_item else "Unknown",
            "category": master_item.category if master_item else "Other",
            "unit": master_item.unit if master_item else "units",
            "initial_quantity": inv.initial_quantity,
            "distributed_quantity": inv.distributed_quantity,
            "remaining_quantity": inv.remaining_quantity,
            "eligibility_type": inv.eligibility_type,
            "semester_filter": inv.semester_filter,
            "low_stock_threshold": inv.low_stock_threshold,
            "image_url": inv.image_url or (master_item.image_url if master_item else None),
            "status": status_label
        })

    # Winners list
    winners_list = []
    for w in event.winners:
        st = w.student
        winners_list.append({
            "id": w.id,
            "student_id": w.student_id,
            "student_uid": st.student_id if st else "",
            "student_name": st.name if st else "",
            "student_roll": st.roll_number if st else "",
            "position": w.position,
            "prize_title": w.prize_title,
            "notes": w.notes
        })

    total_qty = sum(i["initial_quantity"] for i in inv_list)
    dist_qty = sum(i["distributed_quantity"] for i in inv_list)
    rem_qty = sum(i["remaining_quantity"] for i in inv_list)

    return ApiResponse(
        success=True,
        data={
            "id": event.id,
            "event_uid": event.event_uid,
            "name": event.name,
            "event_type": event.event_type,
            "description": event.description,
            "event_date": event.event_date,
            "event_time": event.event_time,
            "venue": event.venue,
            "status": event.status,
            "academic_session_name": event.academic_session.session_name if event.academic_session else "2026-27",
            "semester_scheme": event.semester_scheme,
            "applicable_semesters": sem_list,
            "custom_audience": event.custom_audience,
            "image_url": event.image_url,
            "inventories": inv_list,
            "winners": winners_list,
            "participants_count": len(event.participants),
            "total_quantity": total_qty,
            "distributed_quantity": dist_qty,
            "remaining_quantity": rem_qty,
            "created_at": event.created_at.isoformat()
        }
    )

@router.patch("/{event_id}", response_model=ApiResponse)
def update_event(
    event_id: int,
    data: EventUpdate,
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    event = db.query(Event).filter(Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found.")

    if data.name is not None:
        event.name = data.name.strip()
    if data.event_type is not None:
        event.event_type = data.event_type.strip()
    if data.description is not None:
        event.description = data.description.strip()
    if data.event_date is not None:
        event.event_date = data.event_date.strip()
    if data.event_time is not None:
        event.event_time = data.event_time.strip()
    if data.venue is not None:
        event.venue = data.venue.strip()
    if data.status is not None:
        event.status = data.status.strip()
    if data.applicable_semesters is not None:
        event.applicable_semesters = ",".join(str(s) for s in data.applicable_semesters)
    if data.custom_audience is not None:
        event.custom_audience = data.custom_audience.strip() if data.custom_audience else None
    if data.image_url is not None:
        event.image_url = data.image_url.strip() if data.image_url else None

    db.commit()
    db.refresh(event)

    audit = AuditLog(
        admin_id=admin.id,
        admin_name=admin.full_name,
        action="UPDATE_EVENT",
        entity_type="Event",
        entity_id=event.event_uid,
        new_data=f"Updated {event.name}"
    )
    db.add(audit)
    db.commit()

    return ApiResponse(success=True, message=f"Event '{event.name}' updated successfully.")

@router.post("/{event_id}/archive", response_model=ApiResponse)
def archive_event(
    event_id: int,
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    event = db.query(Event).filter(Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found.")

    event.status = "Archived"
    audit = AuditLog(
        admin_id=admin.id,
        admin_name=admin.full_name,
        action="ARCHIVE_EVENT",
        entity_type="Event",
        entity_id=event.event_uid,
        new_data=f"Archived {event.name}"
    )
    db.add(audit)
    db.commit()

    return ApiResponse(success=True, message=f"Event '{event.name}' archived. Historical records remain fully intact.")

@router.post("/{event_id}/complete", response_model=ApiResponse)
def complete_event(
    event_id: int,
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    """
    CRITICAL REQUIREMENT:
    Complete Event action.
    Validates that EVERY eligible student has either:
      1. Received their allocated item (DISTRIBUTED), OR
      2. Has an updated remark explaining why they did not receive it.
    If ANY eligible student remains pending without a remark, completing the event is blocked.
    If all are accounted for, updates the event status to 'Completed'.
    """
    event = db.query(Event).filter(Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found.")

    if event.status == "Completed":
        return ApiResponse(
            success=True,
            message=f"Event '{event.name}' is already marked as Completed.",
            data={"event_id": event.id, "status": "Completed"}
        )

    event_inventories = db.query(EventInventory).filter(EventInventory.event_id == event_id).all()
    if not event_inventories:
        event.status = "Completed"
        db.commit()
        return ApiResponse(
            success=True,
            message=f"Event '{event.name}' marked as Completed.",
            data={"event_id": event.id, "status": "Completed"}
        )

    winners = db.query(Winner).filter(Winner.event_id == event_id).all()
    winner_set = {w.student_id for w in winners}

    sem_list = [int(x.strip()) for x in event.applicable_semesters.split(",") if x.strip().isdigit()]

    # Query active students in applicable semesters
    students = db.query(Student).filter(
        Student.status == "ACTIVE",
        Student.current_semester.in_(sem_list)
    ).all()

    # Query all distribution records for this event
    existing_dists = db.query(Distribution).filter(Distribution.event_id == event_id).all()
    dist_map = {}
    for d in existing_dists:
        prev = dist_map.get((d.student_id, d.event_inventory_id))
        if not prev or d.status == "DISTRIBUTED" or prev.status != "DISTRIBUTED":
            dist_map[(d.student_id, d.event_inventory_id)] = d

    unaccounted_items = []
    for st in students:
        is_winner = st.id in winner_set
        for inv in event_inventories:
            eligible = False
            if inv.eligibility_type == "ALL":
                eligible = True
            elif inv.eligibility_type == "SEMESTER":
                eligible = (inv.semester_filter is None or st.current_semester == inv.semester_filter)
            elif inv.eligibility_type == "WINNERS":
                eligible = is_winner
            elif inv.eligibility_type == "SELECTED":
                eligible = True

            if not eligible:
                continue

            dist_rec = dist_map.get((st.id, inv.id))
            is_distributed = (dist_rec is not None and dist_rec.status == "DISTRIBUTED")
            has_remark = (dist_rec is not None and bool((dist_rec.remarks or "").strip()))

            if not is_distributed and not has_remark:
                item_name = inv.inventory_item.name if inv.inventory_item else "Item"
                unaccounted_items.append(f"{st.name} ({st.roll_number}) - {item_name}")

    if unaccounted_items:
        sample_str = ", ".join(unaccounted_items[:3])
        more = f" and {len(unaccounted_items) - 3} more" if len(unaccounted_items) > 3 else ""
        raise HTTPException(
            status_code=400,
            detail=(
                f"Cannot complete event! {len(unaccounted_items)} pending student item(s) are unaccounted for "
                f"({sample_str}{more}). Please distribute the items or add a remark and click Update for each "
                f"pending student before completing the event."
            )
        )

    # All eligible students are accounted for!
    old_status = event.status
    event.status = "Completed"

    audit = AuditLog(
        admin_id=admin.id,
        admin_name=admin.full_name,
        action="COMPLETE_EVENT",
        entity_type="Event",
        entity_id=event.event_uid,
        old_data=f"Status: {old_status}",
        new_data=f"Status: Completed (All {len(students)} eligible students distributed or remarked)"
    )
    db.add(audit)
    db.commit()
    db.refresh(event)

    return ApiResponse(
        success=True,
        message=f"Event '{event.name}' ({event.event_uid}) has been successfully marked as Completed!",
        data={"event_id": event.id, "status": "Completed"}
    )

@router.post("/{event_id}/reopen", response_model=ApiResponse)
def reopen_event(
    event_id: int,
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    event = db.query(Event).filter(Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found.")

    old_status = event.status
    event.status = "Ongoing"

    audit = AuditLog(
        admin_id=admin.id,
        admin_name=admin.full_name,
        action="REOPEN_EVENT",
        entity_type="Event",
        entity_id=event.event_uid,
        old_data=f"Status: {old_status}",
        new_data="Status: Ongoing"
    )
    db.add(audit)
    db.commit()
    db.refresh(event)

    return ApiResponse(
        success=True,
        message=f"Event '{event.name}' reopened to Ongoing status.",
        data={"event_id": event.id, "status": "Ongoing"}
    )

@router.delete("/{event_id}", response_model=ApiResponse)
def delete_event(
    event_id: int,
    force: bool = Query(False),
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    event = db.query(Event).filter(Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found.")

    dist_count = db.query(Distribution).filter(Distribution.event_id == event.id).count()
    if dist_count > 0 and not force:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot delete '{event.name}' because {dist_count} reward distributions are recorded. Confirm force delete to permanently remove it."
        )

    # Collect associated inventory items before deleting event_inventory
    ev_inventories = db.query(EventInventory).filter(EventInventory.event_id == event.id).all()
    inventory_item_ids = [ei.inventory_item_id for ei in ev_inventories]

    # Clean up associated child records
    db.query(Distribution).filter(Distribution.event_id == event.id).delete()
    db.query(Winner).filter(Winner.event_id == event.id).delete()
    db.query(EventParticipant).filter(EventParticipant.event_id == event.id).delete()
    db.query(EventInventory).filter(EventInventory.event_id == event.id).delete()

    # Clean up event-created inventory items or items that only belonged to this event
    deleted_items_count = 0
    for it_id in inventory_item_ids:
        it = db.query(InventoryItem).filter(InventoryItem.id == it_id).first()
        if not it:
            continue
        # Check if used in other events
        other_events_count = db.query(EventInventory).filter(
            EventInventory.inventory_item_id == it_id
        ).count()
        # Check if linked to any distributions
        dist_records_count = db.query(Distribution).join(
            EventInventory, Distribution.event_inventory_id == EventInventory.id
        ).filter(EventInventory.inventory_item_id == it_id).count()

        desc_lower = (it.description or "").lower()
        is_event_item = (
            getattr(it, "created_source", "MASTER") == "EVENT"
            or "event allocation" in desc_lower
            or "created for event" in desc_lower
        )

        if other_events_count == 0 and dist_records_count == 0 and (is_event_item or (it.initial_stock or 0) == 0):
            db.delete(it)
            deleted_items_count += 1

    event_name = event.name
    uid = event.event_uid
    db.delete(event)

    audit = AuditLog(
        admin_id=admin.id,
        admin_name=admin.full_name,
        action="DELETE_EVENT",
        entity_type="Event",
        entity_id=str(event_id),
        new_data=f"Deleted event '{event_name}' ({uid}) and cleaned up {deleted_items_count} event inventory items"
    )
    db.add(audit)
    db.commit()

    return ApiResponse(success=True, message=f"Event '{event_name}' ({uid}) and its inventory records deleted successfully.")

# --- Event Inventory Management ---
@router.post("/{event_id}/inventory", response_model=ApiResponse)
def add_event_inventory(
    event_id: int,
    data: EventInventoryCreate,
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    event = db.query(Event).filter(Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found.")

    item = None
    if data.inventory_item_id:
        item = db.query(InventoryItem).filter(InventoryItem.id == data.inventory_item_id).first()
    elif data.item_name and data.item_name.strip():
        name_clean = data.item_name.strip()
        item = db.query(InventoryItem).filter(InventoryItem.name.ilike(name_clean)).first()
        if not item:
            item = InventoryItem(
                name=name_clean,
                category=(data.category or "Other").strip(),
                unit=(data.unit or "units").strip(),
                created_source="EVENT",
                image_url=data.image_url
            )
            db.add(item)
            db.commit()
            db.refresh(item)
        elif data.image_url and not item.image_url:
            item.image_url = data.image_url
            db.commit()

    if not item:
        raise HTTPException(status_code=400, detail="Inventory item ID or valid item name is required.")

    existing = db.query(EventInventory).filter(
        EventInventory.event_id == event_id,
        EventInventory.inventory_item_id == item.id
    ).first()

    if existing:
        raise HTTPException(status_code=400, detail=f"'{item.name}' is already added to this event. You can edit its quantity instead.")

    ev_inv = EventInventory(
        event_id=event_id,
        inventory_item_id=item.id,
        initial_quantity=data.initial_quantity,
        distributed_quantity=0,
        remaining_quantity=data.initial_quantity,
        eligibility_type=data.eligibility_type.upper(),
        semester_filter=data.semester_filter,
        low_stock_threshold=data.low_stock_threshold,
        image_url=data.image_url or (item.image_url if item else None)
    )
    db.add(ev_inv)
    db.commit()
    db.refresh(ev_inv)

    audit = AuditLog(
        admin_id=admin.id,
        admin_name=admin.full_name,
        action="ADD_EVENT_INVENTORY",
        entity_type="EventInventory",
        entity_id=str(ev_inv.id),
        new_data=f"Added {data.initial_quantity}x {item.name} to {event.name} (Eligibility: {ev_inv.eligibility_type})"
    )
    db.add(audit)
    db.commit()

    return ApiResponse(
        success=True,
        data={
            "id": ev_inv.id,
            "item_name": item.name,
            "initial_quantity": ev_inv.initial_quantity,
            "remaining_quantity": ev_inv.remaining_quantity,
            "eligibility_type": ev_inv.eligibility_type
        },
        message=f"{data.initial_quantity} units of '{item.name}' allocated to event."
    )

@router.patch("/{event_id}/inventory/{inventory_id}", response_model=ApiResponse)
def update_event_inventory(
    event_id: int,
    inventory_id: int,
    data: EventInventoryUpdate,
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    ev_inv = db.query(EventInventory).filter(
        EventInventory.id == inventory_id,
        EventInventory.event_id == event_id
    ).first()
    if not ev_inv:
        raise HTTPException(status_code=404, detail="Event inventory record not found.")

    if data.initial_quantity is not None:
        if data.initial_quantity < ev_inv.distributed_quantity:
            raise HTTPException(
                status_code=400,
                detail=f"Cannot set initial quantity to {data.initial_quantity} because {ev_inv.distributed_quantity} units have already been distributed."
            )
        diff = data.initial_quantity - ev_inv.initial_quantity
        ev_inv.initial_quantity = data.initial_quantity
        ev_inv.remaining_quantity += diff

    if data.eligibility_type is not None:
        ev_inv.eligibility_type = data.eligibility_type.upper()
    if data.semester_filter is not None:
        ev_inv.semester_filter = data.semester_filter
    if data.low_stock_threshold is not None:
        ev_inv.low_stock_threshold = data.low_stock_threshold

    db.commit()
    db.refresh(ev_inv)

    return ApiResponse(success=True, message="Inventory settings updated successfully.")

@router.delete("/{event_id}/inventory/{inventory_id}", response_model=ApiResponse)
def remove_event_inventory(
    event_id: int,
    inventory_id: int,
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    ev_inv = db.query(EventInventory).filter(
        EventInventory.id == inventory_id,
        EventInventory.event_id == event_id
    ).first()
    if not ev_inv:
        raise HTTPException(status_code=404, detail="Event inventory record not found.")

    if ev_inv.distributed_quantity > 0:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot remove item because {ev_inv.distributed_quantity} units have already been distributed to students."
        )

    item_id = ev_inv.inventory_item_id
    item_name = ev_inv.inventory_item.name if ev_inv.inventory_item else "Item"

    db.delete(ev_inv)
    db.flush()

    # Check if inventory item was created for event and should be cleaned up
    it = db.query(InventoryItem).filter(InventoryItem.id == item_id).first()
    if it:
        other_events = db.query(EventInventory).filter(EventInventory.inventory_item_id == item_id).count()
        dist_records = db.query(Distribution).join(
            EventInventory, Distribution.event_inventory_id == EventInventory.id
        ).filter(EventInventory.inventory_item_id == item_id).count()
        desc_lower = (it.description or "").lower()
        is_event_item = (
            getattr(it, "created_source", "MASTER") == "EVENT"
            or "event allocation" in desc_lower
            or "created for event" in desc_lower
        )
        if other_events == 0 and dist_records == 0 and (is_event_item or (it.initial_stock or 0) == 0):
            db.delete(it)

    db.commit()
    return ApiResponse(success=True, message=f"Inventory item '{item_name}' removed from event.")

# --- Winner Management ---
@router.post("/{event_id}/winners", response_model=ApiResponse)
def add_event_winner(
    event_id: int,
    data: WinnerCreate,
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    event = db.query(Event).filter(Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found.")

    student = db.query(Student).filter(Student.id == data.student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found.")

    # Check if student is already winner for this event
    existing = db.query(Winner).filter(
        Winner.event_id == event_id,
        Winner.student_id == data.student_id
    ).first()

    if existing:
        existing.position = data.position
        existing.prize_title = data.prize_title
        existing.notes = data.notes
        db.commit()
        return ApiResponse(success=True, message=f"Winner position updated for {student.name}.")

    winner = Winner(
        event_id=event_id,
        student_id=data.student_id,
        position=data.position,
        prize_title=data.prize_title,
        notes=data.notes
    )
    db.add(winner)
    db.commit()
    db.refresh(winner)

    return ApiResponse(
        success=True,
        data={"id": winner.id, "student_name": student.name, "position": winner.position},
        message=f"{student.name} assigned as {winner.position}."
    )

@router.delete("/{event_id}/winners/{winner_id}", response_model=ApiResponse)
def remove_event_winner(
    event_id: int,
    winner_id: int,
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    w = db.query(Winner).filter(Winner.id == winner_id, Winner.event_id == event_id).first()
    if not w:
        raise HTTPException(status_code=404, detail="Winner record not found.")
    db.delete(w)
    db.commit()
    return ApiResponse(success=True, message="Winner removed.")
