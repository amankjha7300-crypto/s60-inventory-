from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Dict, Any
from app.database.session import get_db
from app.models.all_models import AcademicSession, Student, Admin, AuditLog
from app.schemas.schemas import (
    ApiResponse, AcademicSessionCreate, AcademicSessionUpdate,
    AcademicSessionResponse, PromotionConfirmRequest, PromotionPreview
)
from app.api.deps import get_current_admin

router = APIRouter(prefix="/academic-sessions", tags=["Academic Sessions & Schemes"])

def get_active_semesters_for_scheme(scheme: str) -> List[int]:
    return [3, 5, 7] if scheme.upper() == "ODD" else [4, 6, 8]

@router.get("", response_model=ApiResponse)
def list_academic_sessions(
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    sessions = db.query(AcademicSession).order_by(AcademicSession.id.desc()).all()
    results = []
    for s in sessions:
        results.append({
            "id": s.id,
            "session_name": s.session_name,
            "current_scheme": s.current_scheme,
            "is_active": s.is_active,
            "active_semesters": get_active_semesters_for_scheme(s.current_scheme),
            "created_at": s.created_at.isoformat()
        })
    return ApiResponse(success=True, data=results)

@router.get("/current", response_model=ApiResponse)
def get_current_session(
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    session = db.query(AcademicSession).filter(AcademicSession.is_active == True).order_by(AcademicSession.id.desc()).first()
    if not session:
        # Auto-create default 2026-27 ODD session if not exists
        session = AcademicSession(session_name="2026-27", current_scheme="ODD", is_active=True)
        db.add(session)
        db.commit()
        db.refresh(session)
    
    return ApiResponse(
        success=True,
        data={
            "id": session.id,
            "session_name": session.session_name,
            "current_scheme": session.current_scheme,
            "is_active": session.is_active,
            "active_semesters": get_active_semesters_for_scheme(session.current_scheme),
            "created_at": session.created_at.isoformat()
        }
    )

@router.post("", response_model=ApiResponse)
def create_academic_session(
    data: AcademicSessionCreate,
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    existing = db.query(AcademicSession).filter(AcademicSession.session_name == data.session_name).first()
    if existing:
        raise HTTPException(status_code=400, detail=f"Session '{data.session_name}' already exists.")

    scheme = data.current_scheme.upper()
    if scheme not in ["ODD", "EVEN"]:
        raise HTTPException(status_code=400, detail="Scheme must be either ODD or EVEN.")

    if data.is_active:
        # Set all others inactive
        db.query(AcademicSession).update({AcademicSession.is_active: False})

    new_session = AcademicSession(
        session_name=data.session_name,
        current_scheme=scheme,
        is_active=data.is_active
    )
    db.add(new_session)
    db.commit()
    db.refresh(new_session)

    audit = AuditLog(
        admin_id=admin.id,
        admin_name=admin.full_name,
        action="CREATE_SESSION",
        entity_type="AcademicSession",
        entity_id=str(new_session.id),
        new_data=f"Created {new_session.session_name} ({new_session.current_scheme})"
    )
    db.add(audit)
    db.commit()

    return ApiResponse(
        success=True,
        data={
            "id": new_session.id,
            "session_name": new_session.session_name,
            "current_scheme": new_session.current_scheme,
            "is_active": new_session.is_active,
            "active_semesters": get_active_semesters_for_scheme(new_session.current_scheme),
            "created_at": new_session.created_at.isoformat()
        },
        message=f"Academic session {new_session.session_name} created successfully."
    )

@router.patch("/{session_id}", response_model=ApiResponse)
def update_academic_session(
    session_id: int,
    data: AcademicSessionUpdate,
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    session = db.query(AcademicSession).filter(AcademicSession.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Academic session not found.")

    if data.session_name is not None:
        session.session_name = data.session_name
    if data.current_scheme is not None:
        scheme = data.current_scheme.upper()
        if scheme not in ["ODD", "EVEN"]:
            raise HTTPException(status_code=400, detail="Scheme must be ODD or EVEN.")
        session.current_scheme = scheme
    if data.is_active is not None:
        if data.is_active:
            db.query(AcademicSession).filter(AcademicSession.id != session.id).update({AcademicSession.is_active: False})
        session.is_active = data.is_active

    db.commit()
    db.refresh(session)

    return ApiResponse(
        success=True,
        data={
            "id": session.id,
            "session_name": session.session_name,
            "current_scheme": session.current_scheme,
            "is_active": session.is_active,
            "active_semesters": get_active_semesters_for_scheme(session.current_scheme)
        },
        message="Session updated successfully."
    )

@router.get("/{session_id}/promote-preview", response_model=ApiResponse)
def preview_promotion(
    session_id: int,
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    session = db.query(AcademicSession).filter(AcademicSession.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found.")

    active_students = db.query(Student).filter(
        Student.status == "ACTIVE"
    ).all()

    current_scheme = session.current_scheme.upper()
    target_scheme = "EVEN" if current_scheme == "ODD" else "ODD"

    # Odd -> Even: 3->4, 5->6, 7->8
    # Even -> Odd: 4->5, 6->7, 8->Graduated
    transitions: Dict[str, int] = {}
    if current_scheme == "ODD":
        transitions["3rd → 4th Semester"] = sum(1 for s in active_students if s.current_semester == 3)
        transitions["5th → 6th Semester"] = sum(1 for s in active_students if s.current_semester == 5)
        transitions["7th → 8th Semester"] = sum(1 for s in active_students if s.current_semester == 7)
    else:
        transitions["4th → 5th Semester"] = sum(1 for s in active_students if s.current_semester == 4)
        transitions["6th → 7th Semester"] = sum(1 for s in active_students if s.current_semester == 6)
        transitions["8th → Completed / Alumni"] = sum(1 for s in active_students if s.current_semester == 8)

    return ApiResponse(
        success=True,
        data={
            "session_id": session.id,
            "session_name": session.session_name,
            "scheme_from": current_scheme,
            "scheme_to": target_scheme,
            "total_active_students": len(active_students),
            "transitions": transitions,
            "confirmation_message": f"Are you sure you want to promote all active students from {current_scheme} to {target_scheme} scheme? Student IDs and past reward history will remain untouched."
        }
    )

@router.post("/{session_id}/promote", response_model=ApiResponse)
def execute_promotion(
    session_id: int,
    db: Session = Depends(get_db),
    admin: Admin = Depends(get_current_admin)
):
    session = db.query(AcademicSession).filter(AcademicSession.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Academic session not found.")

    current_scheme = session.current_scheme.upper()
    active_students = db.query(Student).filter(Student.status == "ACTIVE").all()

    promoted_count = 0
    graduated_count = 0
    transitions_done = {}

    if current_scheme == "ODD":
        # 3 -> 4, 5 -> 6, 7 -> 8
        for s in active_students:
            if s.current_semester == 3:
                s.current_semester = 4
                promoted_count += 1
            elif s.current_semester == 5:
                s.current_semester = 6
                promoted_count += 1
            elif s.current_semester == 7:
                s.current_semester = 8
                promoted_count += 1
        session.current_scheme = "EVEN"
        transitions_done = {"3→4": True, "5→6": True, "7→8": True}
    else:
        # 4 -> 5, 6 -> 7, 8 -> COMPLETED
        for s in active_students:
            if s.current_semester == 4:
                s.current_semester = 5
                promoted_count += 1
            elif s.current_semester == 6:
                s.current_semester = 7
                promoted_count += 1
            elif s.current_semester == 8:
                s.status = "COMPLETED"
                graduated_count += 1
        session.current_scheme = "ODD"
        transitions_done = {"4→5": True, "6→7": True, "8→Graduated": True}

    audit = AuditLog(
        admin_id=admin.id,
        admin_name=admin.full_name,
        action="SEMESTER_PROMOTION",
        entity_type="AcademicSession",
        entity_id=str(session.id),
        old_data=f"Scheme: {current_scheme}",
        new_data=f"Promoted {promoted_count} students to {session.current_scheme}. Graduated: {graduated_count}"
    )
    db.add(audit)
    db.commit()

    return ApiResponse(
        success=True,
        data={
            "promoted_count": promoted_count,
            "graduated_count": graduated_count,
            "new_scheme": session.current_scheme,
            "active_semesters": get_active_semesters_for_scheme(session.current_scheme)
        },
        message=f"Semester promotion complete! {promoted_count} students transitioned. Scheme is now {session.current_scheme}."
    )
