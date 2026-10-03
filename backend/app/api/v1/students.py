from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File
from sqlalchemy.orm import Session
from sqlalchemy import or_
from typing import Optional, List
import csv
import io

from app.database.session import get_db
from app.models.all_models import Student, AcademicSession, Distribution, Winner, Event, InventoryItem, AuditLog, Admin
from app.schemas.schemas import (
    ApiResponse, StudentCreate, StudentUpdate, StudentResponse,
    StudentProfileDetail, StudentRewardItem, WinnerResponse, BulkImportResult, BulkImportStudentItem
)
from app.api.deps import get_current_admin

router = APIRouter(prefix="/students", tags=["Students"])

@router.get("", response_model=ApiResponse)
def list_students(
    search: Optional[str] = Query(None, description="Search by name, student_id, roll_number"),
    semester: Optional[int] = Query(None, description="Filter by semester (3,4,5,6,7,8)"),
    status: Optional[str] = Query("ACTIVE", description="ACTIVE, INACTIVE, ALL"),
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    query = db.query(Student)

    if status and status.upper() != "ALL":
        query = query.filter(Student.status == status.upper())

    if semester:
        query = query.filter(Student.current_semester == semester)

    if search:
        s = f"%{search.strip()}%"
        query = query.filter(
            or_(
                Student.name.ilike(s),
                Student.student_id.ilike(s),
                Student.roll_number.ilike(s),
                Student.email.ilike(s)
            )
        )

    total_count = query.count()
    students = query.order_by(Student.student_id.asc()).offset((page - 1) * page_size).limit(page_size).all()

    items = [
        {
            "id": st.id,
            "student_id": st.student_id,
            "roll_number": st.roll_number,
            "name": st.name,
            "email": st.email,
            "phone": st.phone,
            "branch": st.branch,
            "batch": st.batch,
            "current_semester": st.current_semester,
            "status": st.status,
            "academic_session_id": st.academic_session_id,
            "created_at": st.created_at.isoformat()
        }
        for st in students
    ]

    return ApiResponse(
        success=True,
        data={
            "items": items,
            "total": total_count,
            "page": page,
            "page_size": page_size,
            "total_pages": (total_count + page_size - 1) // page_size
        }
    )

@router.post("", response_model=ApiResponse)
def create_student(
    data: StudentCreate,
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    # Check uniqueness
    existing_sid = db.query(Student).filter(Student.student_id.ilike(data.student_id.strip())).first()
    if existing_sid:
        raise HTTPException(status_code=400, detail=f"Student ID '{data.student_id}' is already registered.")

    existing_roll = db.query(Student).filter(Student.roll_number.ilike(data.roll_number.strip())).first()
    if existing_roll:
        raise HTTPException(status_code=400, detail=f"Roll number '{data.roll_number}' is already registered.")

    if data.current_semester < 1 or data.current_semester > 8:
        raise HTTPException(status_code=400, detail="Invalid semester. Must be between 1 and 8.")

    active_session = db.query(AcademicSession).filter(AcademicSession.is_active == True).first()
    session_id = data.academic_session_id or (active_session.id if active_session else None)

    student = Student(
        student_id=data.student_id.strip().upper(),
        roll_number=data.roll_number.strip().upper(),
        name=data.name.strip(),
        email=data.email.strip() if data.email else None,
        phone=data.phone.strip() if data.phone else None,
        branch=data.branch.strip(),
        batch=data.batch.strip(),
        current_semester=data.current_semester,
        academic_session_id=session_id,
        status=data.status.upper()
    )
    db.add(student)
    db.commit()
    db.refresh(student)

    audit = AuditLog(
        admin_id=admin.id,
        admin_name=admin.full_name,
        action="CREATE_STUDENT",
        entity_type="Student",
        entity_id=student.student_id,
        new_data=f"{student.name} ({student.roll_number}), Sem {student.current_semester}"
    )
    db.add(audit)
    db.commit()

    return ApiResponse(
        success=True,
        data={
            "id": student.id,
            "student_id": student.student_id,
            "roll_number": student.roll_number,
            "name": student.name,
            "current_semester": student.current_semester,
            "status": student.status
        },
        message=f"Student '{student.name}' added successfully."
    )

@router.get("/{student_id}", response_model=ApiResponse)
def get_student_profile(
    student_id: int,
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found.")

    # Historical distributions
    distributions = db.query(Distribution).filter(
        Distribution.student_id == student.id,
        Distribution.status == "DISTRIBUTED"
    ).order_by(Distribution.distributed_at.desc()).all()

    reward_history = []
    events_attended = set()
    for d in distributions:
        events_attended.add(d.event_id)
        ev = d.event
        inv = d.event_inventory.inventory_item if d.event_inventory else None
        reward_history.append({
            "distribution_id": d.id,
            "event_id": d.event_id,
            "event_name": ev.name if ev else "Unknown Event",
            "event_date": ev.event_date if ev else "",
            "item_name": inv.name if inv else "Item",
            "category": inv.category if inv else "Other",
            "quantity": d.quantity,
            "semester_at_distribution": d.semester_at_distribution,
            "session_at_distribution": d.session_at_distribution,
            "distributed_at": d.distributed_at.isoformat(),
            "distributed_by": d.distributed_by_name
        })

    # Competition wins
    wins = db.query(Winner).filter(Winner.student_id == student.id).all()
    wins_list = []
    for w in wins:
        wins_list.append({
            "id": w.id,
            "student_id": student.id,
            "student_uid": student.student_id,
            "student_name": student.name,
            "student_roll": student.roll_number,
            "position": w.position,
            "prize_title": w.prize_title,
            "notes": w.notes,
            "event_name": w.event.name if w.event else ""
        })

    return ApiResponse(
        success=True,
        data={
            "student": {
                "id": student.id,
                "student_id": student.student_id,
                "roll_number": student.roll_number,
                "name": student.name,
                "email": student.email,
                "phone": student.phone,
                "branch": student.branch,
                "batch": student.batch,
                "current_semester": student.current_semester,
                "status": student.status,
                "created_at": student.created_at.isoformat()
            },
            "reward_history": reward_history,
            "wins": wins_list,
            "total_rewards_received": len(distributions),
            "total_events_attended": len(events_attended)
        }
    )

@router.patch("/{student_id}", response_model=ApiResponse)
def update_student(
    student_id: int,
    data: StudentUpdate,
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found.")

    if data.name is not None:
        student.name = data.name.strip()
    if data.email is not None:
        student.email = data.email.strip()
    if data.phone is not None:
        student.phone = data.phone.strip()
    if data.branch is not None:
        student.branch = data.branch.strip()
    if data.batch is not None:
        student.batch = data.batch.strip()
    if data.current_semester is not None:
        student.current_semester = data.current_semester
    if data.status is not None:
        student.status = data.status.upper()

    db.commit()
    db.refresh(student)

    return ApiResponse(success=True, message=f"Student '{student.name}' updated successfully.")

@router.post("/{student_id}/deactivate", response_model=ApiResponse)
def deactivate_student(
    student_id: int,
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found.")

    student.status = "INACTIVE"
    audit = AuditLog(
        admin_id=admin.id,
        admin_name=admin.full_name,
        action="DEACTIVATE_STUDENT",
        entity_type="Student",
        entity_id=student.student_id,
        new_data=f"Deactivated {student.name}. Historical rewards preserved."
    )
    db.add(audit)
    db.commit()

    return ApiResponse(
        success=True,
        message=f"Student {student.name} deactivated. All historical reward records remain preserved."
    )

@router.post("/{student_id}/activate", response_model=ApiResponse)
def activate_student(
    student_id: int,
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found.")

    student.status = "ACTIVE"
    db.commit()

    return ApiResponse(success=True, message=f"Student {student.name} activated.")

@router.delete("/{student_id}", response_model=ApiResponse)
def delete_student(
    student_id: int,
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found.")

    # Check for historical distributions
    dist_count = db.query(Distribution).filter(Distribution.student_id == student.id).count()
    if dist_count > 0:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot delete '{student.name}' because {dist_count} historical distribution records exist. Please use Deactivate instead to preserve records."
        )

    db.delete(student)
    db.commit()
    return ApiResponse(success=True, message=f"Student '{student.name}' removed.")

@router.post("/import", response_model=ApiResponse)
def bulk_import_students(
    items: List[BulkImportStudentItem],
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    active_session = db.query(AcademicSession).filter(AcademicSession.is_active == True).first()
    session_id = active_session.id if active_session else None

    imported = 0
    skipped = 0
    errors = []

    for item in items:
        sid = item.student_id.strip().upper()
        roll = item.roll_number.strip().upper()

        if not sid or not roll or not item.name.strip():
            skipped += 1
            errors.append(f"Missing required fields for student: {item.name}")
            continue

        if item.semester < 1 or item.semester > 8:
            skipped += 1
            errors.append(f"Invalid semester {item.semester} for student: {sid}")
            continue

        # Check existing
        existing = db.query(Student).filter(
            or_(Student.student_id == sid, Student.roll_number == roll)
        ).first()

        if existing:
            skipped += 1
            errors.append(f"Duplicate student ID ({sid}) or Roll Number ({roll})")
            continue

        st = Student(
            student_id=sid,
            roll_number=roll,
            name=item.name.strip(),
            email=item.email.strip() if item.email else None,
            phone=item.phone.strip() if item.phone else None,
            batch=item.batch.strip() if item.batch else "2025",
            current_semester=item.semester,
            academic_session_id=session_id,
            status="ACTIVE"
        )
        db.add(st)
        imported += 1

    db.commit()

    audit = AuditLog(
        admin_id=admin.id,
        admin_name=admin.full_name,
        action="BULK_IMPORT_STUDENTS",
        entity_type="Student",
        entity_id=None,
        new_data=f"Imported: {imported}, Skipped: {skipped}"
    )
    db.add(audit)
    db.commit()

    return ApiResponse(
        success=True,
        data={
            "imported_count": imported,
            "skipped_count": skipped,
            "errors": errors[:20]  # First 20 errors
        },
        message=f"Bulk import processed: {imported} imported, {skipped} skipped."
    )
