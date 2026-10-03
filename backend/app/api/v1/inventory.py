from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import or_
from typing import Optional, List
from app.database.session import get_db
from app.models.all_models import InventoryItem, EventInventory, AuditLog, Admin
from app.schemas.schemas import (
    ApiResponse, InventoryItemCreate, InventoryItemResponse,
    EventInventoryCreate, EventInventoryUpdate, EventInventoryResponse
)
from app.api.deps import get_current_admin

router = APIRouter(prefix="/inventory", tags=["Master Inventory"])

@router.get("", response_model=ApiResponse)
def list_inventory_items(
    search: Optional[str] = Query(None),
    category: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    query = db.query(InventoryItem)
    if search:
        s = f"%{search.strip()}%"
        query = query.filter(or_(InventoryItem.name.ilike(s), InventoryItem.category.ilike(s)))
    if category and category.upper() != "ALL":
        query = query.filter(InventoryItem.category.ilike(category.strip()))

    items = query.order_by(InventoryItem.name.asc()).all()

    # Calculate global allocated, distributed, remaining across events
    results = []
    for item in items:
        event_allocs = db.query(EventInventory).filter(EventInventory.inventory_item_id == item.id).all()
        total_initial = sum(ea.initial_quantity for ea in event_allocs)
        total_distributed = sum(ea.distributed_quantity for ea in event_allocs)
        total_remaining = sum(ea.remaining_quantity for ea in event_allocs)

        results.append({
            "id": item.id,
            "name": item.name,
            "category": item.category,
            "unit": item.unit,
            "description": item.description,
            "default_sku": item.default_sku,
            "total_allocated": total_initial,
            "total_distributed": total_distributed,
            "total_remaining": total_remaining,
            "events_count": len(event_allocs),
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

    item = InventoryItem(
        name=data.name.strip(),
        category=data.category.strip(),
        unit=data.unit.strip(),
        description=data.description.strip() if data.description else None,
        default_sku=data.default_sku.strip() if data.default_sku else None
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
        new_data=f"Created {item.name} ({item.category})"
    )
    db.add(audit)
    db.commit()

    return ApiResponse(
        success=True,
        data={
            "id": item.id,
            "name": item.name,
            "category": item.category,
            "unit": item.unit
        },
        message=f"Inventory item '{item.name}' added successfully."
    )

@router.patch("/{item_id}", response_model=ApiResponse)
def update_inventory_item(
    item_id: int,
    data: InventoryItemCreate,
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    item = db.query(InventoryItem).filter(InventoryItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found.")

    item.name = data.name.strip()
    item.category = data.category.strip()
    item.unit = data.unit.strip()
    if data.description is not None:
        item.description = data.description.strip()

    db.commit()
    return ApiResponse(success=True, message=f"Item '{item.name}' updated.")
