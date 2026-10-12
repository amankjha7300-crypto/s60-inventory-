from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import or_
from typing import Optional, List
import datetime
from app.database.session import get_db
from app.models.all_models import (
    InventoryItem, EventInventory, Distribution, Student, Event, AuditLog, Admin
)
from app.schemas.schemas import (
    ApiResponse, InventoryItemCreate, InventoryItemUpdate, InventoryItemResponse,
    MasterItemDistributeRequest, EventInventoryCreate, EventInventoryUpdate, EventInventoryResponse
)
from app.api.deps import get_current_admin

router = APIRouter(prefix="/inventory", tags=["Master Inventory"])

def utcnow():
    return datetime.datetime.now(datetime.timezone.utc)

@router.get("", response_model=ApiResponse)
def list_inventory_items(
    search: Optional[str] = Query(None),
    category: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    query = db.query(InventoryItem)
    if search and isinstance(search, str):
        s = f"%{search.strip()}%"
        query = query.filter(or_(InventoryItem.name.ilike(s), InventoryItem.category.ilike(s)))
    if category and isinstance(category, str) and category.upper() != "ALL":
        query = query.filter(InventoryItem.category.ilike(category.strip()))

    items = query.order_by(InventoryItem.name.asc()).all()

    # Calculate global allocated, distributed, remaining across events & master stock
    results = []
    for item in items:
        event_allocs = db.query(EventInventory).filter(EventInventory.inventory_item_id == item.id).all()
        total_event_initial = sum(ea.initial_quantity for ea in event_allocs)
        total_distributed = sum(ea.distributed_quantity for ea in event_allocs)

        # Base units defined in master inventory
        base_stock = item.initial_stock or 0
        # If legacy record has numeric string in unit (e.g. "52.", "80"), extract as stock fallback
        if base_stock == 0 and item.unit:
            try:
                clean_u = item.unit.replace(".", "").strip()
                if clean_u.isdigit():
                    base_stock = int(clean_u)
            except Exception:
                pass

        # Auto-sync single event allocations with item.initial_stock if desynced
        if len(event_allocs) == 1 and item.initial_stock is not None and item.initial_stock > 0 and event_allocs[0].initial_quantity != item.initial_stock:
            ev = event_allocs[0]
            if item.initial_stock >= ev.distributed_quantity:
                ev.initial_quantity = item.initial_stock
                ev.remaining_quantity = max(0, item.initial_stock - ev.distributed_quantity)
                db.commit()
                total_event_initial = item.initial_stock

        total_allocated = item.initial_stock if (item.initial_stock is not None and item.initial_stock > 0) else max(base_stock, total_event_initial)
        total_remaining = max(0, total_allocated - total_distributed)

        desc_lower = (item.description or "").lower()
        is_event_created = (
            getattr(item, "created_source", "MASTER") == "EVENT"
            or "event allocation" in desc_lower
            or "created for event" in desc_lower
        )

        event_ids = [ea.event_id for ea in event_allocs]
        events_info = [
            {
                "id": ea.event.id,
                "name": ea.event.name,
                "event_uid": ea.event.event_uid,
                "initial_quantity": ea.initial_quantity,
                "distributed_quantity": ea.distributed_quantity,
                "remaining_quantity": ea.remaining_quantity
            }
            for ea in event_allocs if ea.event
        ]
        results.append({
            "id": item.id,
            "name": item.name,
            "category": item.category,
            "unit": item.unit,
            "description": item.description,
            "default_sku": item.default_sku,
            "initial_stock": total_allocated,
            "total_allocated": total_allocated,
            "total_distributed": total_distributed,
            "total_remaining": total_remaining,
            "events_count": len(event_allocs),
            "event_ids": event_ids,
            "events": events_info,
            "first_event_id": event_ids[0] if event_ids else None,
            "created_source": "EVENT" if is_event_created else "MASTER",
            "is_event_created": is_event_created,
            "image_url": item.image_url,
            "created_at": item.created_at.isoformat()
        })

    return ApiResponse(success=True, data=results)

@router.post("", response_model=ApiResponse)
def create_inventory_item(
    data: InventoryItemCreate,
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    existing = db.query(InventoryItem).filter(InventoryItem.name.ilike(data.name.strip())).first()
    if existing:
        raise HTTPException(status_code=400, detail=f"Item '{data.name}' already exists in inventory.")

    initial_stock_val = data.initial_stock or 0
    source_val = data.created_source or ("EVENT" if data.description and ("event allocation" in data.description.lower() or "created for event" in data.description.lower()) else "MASTER")
    item = InventoryItem(
        name=data.name.strip(),
        category=data.category.strip(),
        unit=data.unit.strip() if data.unit else "units",
        description=data.description.strip() if data.description else None,
        default_sku=data.default_sku.strip() if data.default_sku else None,
        initial_stock=initial_stock_val,
        created_source=source_val,
        image_url=data.image_url
    )
    db.add(item)
    db.commit()
    db.refresh(item)

    audit = AuditLog(
        admin_id=admin.id,
        admin_name=admin.full_name,
        action="CREATE_INVENTORY_ITEM",
        entity_type="InventoryItem",
        entity_id=str(item.id),
        new_data=f"Created {item.name} ({item.category}) with {initial_stock_val} units in Master Inventory"
    )
    db.add(audit)
    db.commit()

    return ApiResponse(
        success=True,
        data={
            "id": item.id,
            "name": item.name,
            "category": item.category,
            "unit": item.unit,
            "initial_stock": item.initial_stock,
            "total_allocated": item.initial_stock,
            "total_distributed": 0,
            "total_remaining": item.initial_stock,
            "created_source": "MASTER",
            "image_url": item.image_url,
            "is_event_created": False
        },
        message=f"Inventory item '{item.name}' added with {initial_stock_val} units."
    )

@router.patch("/{item_id}", response_model=ApiResponse)
def update_inventory_item(
    item_id: int,
    data: InventoryItemUpdate,
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    item = db.query(InventoryItem).filter(InventoryItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found.")

    if data.name is not None and data.name.strip():
        item.name = data.name.strip()
    if data.category is not None and data.category.strip():
        item.category = data.category.strip()
    if data.unit is not None and data.unit.strip():
        item.unit = data.unit.strip()
    if data.description is not None:
        item.description = data.description.strip()
    if data.image_url is not None:
        item.image_url = data.image_url

    if data.initial_stock is not None:
        new_stock = max(0, data.initial_stock)
        event_allocs = db.query(EventInventory).filter(EventInventory.inventory_item_id == item.id).all()
        total_distributed = sum(ea.distributed_quantity for ea in event_allocs)

        if new_stock < total_distributed:
            raise HTTPException(
                status_code=400,
                detail=f"Cannot set allocated units to {new_stock} because {total_distributed} units have already been distributed to students."
            )

        item.initial_stock = new_stock

        if len(event_allocs) == 1:
            ev = event_allocs[0]
            ev.initial_quantity = new_stock
            ev.remaining_quantity = max(0, new_stock - ev.distributed_quantity)
        elif len(event_allocs) > 1:
            current_event_total = sum(ea.initial_quantity for ea in event_allocs)
            diff = new_stock - current_event_total
            if diff > 0:
                latest_ev = event_allocs[-1]
                latest_ev.initial_quantity += diff
                latest_ev.remaining_quantity += diff
            elif diff < 0:
                to_deduct = abs(diff)
                for ev in reversed(event_allocs):
                    can_deduct = max(0, ev.initial_quantity - ev.distributed_quantity)
                    deduct = min(to_deduct, can_deduct)
                    ev.initial_quantity -= deduct
                    ev.remaining_quantity = max(0, ev.initial_quantity - ev.distributed_quantity)
                    to_deduct -= deduct
                    if to_deduct <= 0:
                        break

        audit = AuditLog(
            admin_id=admin.id,
            admin_name=admin.full_name,
            action="UPDATE_INVENTORY_STOCK",
            entity_type="InventoryItem",
            entity_id=str(item.id),
            new_data=f"Updated allocated stock of '{item.name}' to {new_stock} units"
        )
        db.add(audit)

    db.commit()
    db.refresh(item)
    return ApiResponse(
        success=True, 
        message=f"Item '{item.name}' updated successfully.",
        data={
            "id": item.id,
            "name": item.name,
            "category": item.category,
            "unit": item.unit,
            "initial_stock": item.initial_stock
        }
    )

@router.delete("/{item_id}", response_model=ApiResponse)
def delete_inventory_item(
    item_id: int,
    force: bool = Query(False),
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    item = db.query(InventoryItem).filter(InventoryItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Inventory item not found.")

    # Check for recorded distributions
    dist_count = db.query(Distribution).join(
        EventInventory, Distribution.event_inventory_id == EventInventory.id
    ).filter(EventInventory.inventory_item_id == item.id).count()
    if dist_count > 0 and not force:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot delete '{item.name}' because {dist_count} student reward distributions are recorded. Deletion would compromise historical records."
        )

    # Check if item is linked to active events
    active_event_count = db.query(EventInventory).filter(EventInventory.inventory_item_id == item.id).count()
    if active_event_count > 0 and not force:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot delete '{item.name}' because it is currently allocated to {active_event_count} event(s). Remove it from the respective event(s) first."
        )

    # Clean up associated event inventory allocations and distributions if force is enabled
    event_invs = db.query(EventInventory).filter(EventInventory.inventory_item_id == item.id).all()
    for ei in event_invs:
        db.query(Distribution).filter(Distribution.event_inventory_id == ei.id).delete()
    db.query(EventInventory).filter(EventInventory.inventory_item_id == item.id).delete()

    item_name = item.name
    db.delete(item)

    audit = AuditLog(
        admin_id=admin.id,
        admin_name=admin.full_name,
        action="DELETE_INVENTORY_ITEM",
        entity_type="InventoryItem",
        entity_id=str(item_id),
        new_data=f"Deleted inventory item '{item_name}'"
    )
    db.add(audit)
    db.commit()

    return ApiResponse(success=True, message=f"Inventory item '{item_name}' deleted successfully.")

@router.post("/{item_id}/distribute", response_model=ApiResponse)
def distribute_master_item(
    item_id: int,
    data: MasterItemDistributeRequest,
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    """
    Distribute a master inventory item to a student under an event (or direct general distribution) directly from Master Inventory.
    """
    item = db.query(InventoryItem).filter(InventoryItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Inventory item not found.")

    student = db.query(Student).filter(Student.id == data.student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found.")

    # Target event is optional: if not provided, use/create the default General Distribution event
    if not data.event_id:
        gen_event = db.query(Event).filter(Event.event_uid == "S60-GEN-0001").first()
        if not gen_event:
            gen_event = Event(
                event_uid="S60-GEN-0001",
                name="General / Master Stock Distribution",
                event_type="General",
                description="General departmental reward distribution directly from master catalog.",
                event_date=datetime.datetime.now().strftime("%d %b %Y"),
                status="Ongoing",
                semester_scheme="ALL",
                applicable_semesters="3,4,5,6,7,8"
            )
            db.add(gen_event)
            db.commit()
            db.refresh(gen_event)
        event = gen_event
        data.event_id = gen_event.id
    else:
        event = db.query(Event).filter(Event.id == data.event_id).first()
        if not event:
            raise HTTPException(status_code=404, detail="Event not found.")

    qty = max(1, data.quantity)

    # Find or create EventInventory
    ev_inv = db.query(EventInventory).filter(
        EventInventory.event_id == data.event_id,
        EventInventory.inventory_item_id == item_id
    ).with_for_update().first()

    if not ev_inv:
        # Auto-link master item to event with initial allocation
        ev_inv = EventInventory(
            event_id=data.event_id,
            inventory_item_id=item_id,
            initial_quantity=qty,
            distributed_quantity=0,
            remaining_quantity=qty,
            eligibility_type="ALL"
        )
        db.add(ev_inv)
        db.flush()
    else:
        # Check stock in event; if remaining is less than qty but master stock exists, adjust
        if ev_inv.remaining_quantity < qty:
            base_stock = item.initial_stock or 0
            event_total = db.query(EventInventory).filter(EventInventory.inventory_item_id == item.id).all()
            all_dist = sum(x.distributed_quantity for x in event_total)
            if base_stock > all_dist:
                needed = qty - ev_inv.remaining_quantity
                ev_inv.initial_quantity += needed
                ev_inv.remaining_quantity += needed
            else:
                raise HTTPException(
                    status_code=400,
                    detail=f"Insufficient remaining quantity for '{item.name}'. Only {ev_inv.remaining_quantity} available."
                )

    # Check for existing distribution
    existing = db.query(Distribution).filter(
        Distribution.event_id == data.event_id,
        Distribution.student_id == data.student_id,
        Distribution.event_inventory_id == ev_inv.id,
        Distribution.status == "DISTRIBUTED"
    ).first()

    if existing:
        raise HTTPException(
            status_code=400,
            detail=f"{student.name} ({student.student_id}) has already received '{item.name}' for event '{event.name}'."
        )

    # Create Distribution record
    session_name = event.academic_session.session_name if (event and event.academic_session) else "2026-27"
    dist = Distribution(
        event_id=data.event_id,
        student_id=data.student_id,
        event_inventory_id=ev_inv.id,
        quantity=qty,
        status="DISTRIBUTED",
        distributed_at=utcnow(),
        distributed_by_id=admin.id,
        distributed_by_name=admin.full_name,
        semester_at_distribution=student.current_semester,
        session_at_distribution=session_name,
        remarks=data.remarks or "Distributed via Master Inventory"
    )
    db.add(dist)

    # Update event inventory counts
    ev_inv.distributed_quantity += qty
    ev_inv.remaining_quantity = max(0, ev_inv.remaining_quantity - qty)

    # Audit log
    audit = AuditLog(
        admin_id=admin.id,
        admin_name=admin.full_name,
        action="DISTRIBUTE_MASTER_ITEM",
        entity_type="Distribution",
        entity_id=str(dist.id),
        new_data=f"Distributed {qty} {item.name} to {student.name} ({student.student_id}) for {event.name}"
    )
    db.add(audit)
    db.commit()

    return ApiResponse(
        success=True,
        data={
            "student_name": student.name,
            "student_id": student.student_id,
            "item_name": item.name,
            "quantity": qty,
            "event_name": event.name,
            "remaining_quantity": ev_inv.remaining_quantity
        },
        message=f"Successfully distributed {qty} {item.name} to {student.name} ({student.student_id})!"
    )
