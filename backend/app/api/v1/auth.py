from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database.session import get_db
from app.models.all_models import Admin, AuditLog
from app.schemas.schemas import (
    LoginRequest, SignUpRequest, TokenResponse, ApiResponse, AdminResponse,
    ResetPasswordRequest, AdminResetPasswordRequest
)
from app.core.security import verify_password, create_access_token, get_password_hash
from app.api.deps import get_current_admin, require_super_admin
from pydantic import BaseModel
import random

router = APIRouter(prefix="/auth", tags=["Authentication"])

class ChangePasswordRequest(BaseModel):
    old_password: str
    new_password: str

@router.post("/signup", response_model=ApiResponse)
@router.post("/register", response_model=ApiResponse)
def signup(data: SignUpRequest, db: Session = Depends(get_db)):
    email = data.email.strip().lower()
    full_name = data.full_name.strip()
    
    if not full_name:
        raise HTTPException(status_code=400, detail="Full name is required.")
    if len(data.password) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters.")
    
    # Check existing email
    if db.query(Admin).filter(Admin.email.ilike(email)).first():
        raise HTTPException(status_code=400, detail=f"Account with email '{email}' already exists. Please sign in.")
    
    # Username generation / validation
    username = (data.username.strip().lower() if data.username else email.split("@")[0]).replace(" ", "_")
    if db.query(Admin).filter(Admin.username.ilike(username)).first():
        username = f"{username}_{random.randint(100, 999)}"
    
    # Role validation - 3 Core Designations: Inventory Coordinator, Head of Department, Super Admin
    role_input = (data.role or "COORDINATOR").strip().upper()
    if role_input in ["INVENTORY_COORDINATOR", "COORDINATOR"]:
        role = "COORDINATOR"
    elif role_input in ["HOD", "HEAD_OF_DEPARTMENT"]:
        role = "HOD"
    elif role_input == "SUPER_ADMIN":
        role = "SUPER_ADMIN"
    else:
        role = "COORDINATOR"
    
    new_admin = Admin(
        username=username,
        email=email,
        full_name=full_name,
        password_hash=get_password_hash(data.password),
        role=role,
        is_active=True
    )
    db.add(new_admin)
    db.commit()
    db.refresh(new_admin)
    
    audit = AuditLog(
        admin_id=new_admin.id,
        admin_name=new_admin.full_name,
        action="SIGNUP",
        entity_type="Admin",
        entity_id=str(new_admin.id),
        new_data=f"Created {new_admin.role} account for {new_admin.full_name} ({new_admin.email})"
    )
    db.add(audit)
    db.commit()
    
    access_token = create_access_token(
        data={"sub": str(new_admin.id), "email": new_admin.email, "role": new_admin.role}
    )
    
    admin_data = {
        "id": new_admin.id,
        "username": new_admin.username,
        "email": new_admin.email,
        "full_name": new_admin.full_name,
        "role": new_admin.role
    }
    
    return ApiResponse(
        success=True,
        data={
            "access_token": access_token,
            "token_type": "bearer",
            "admin": admin_data
        },
        message=f"Account created successfully! Welcome to Super60, {new_admin.full_name}."
    )

@router.post("/login", response_model=ApiResponse)
def login(login_data: LoginRequest, db: Session = Depends(get_db)):
    email_or_user = login_data.email.strip().lower()
    admin = db.query(Admin).filter(
        (Admin.email.ilike(email_or_user)) | (Admin.username.ilike(email_or_user))
    ).first()

    if not admin or not verify_password(login_data.password, admin.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email/username or password."
        )

    if not admin.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This administrator account has been deactivated."
        )

    access_token = create_access_token(
        data={"sub": str(admin.id), "email": admin.email, "role": admin.role}
    )


    admin_data = {
        "id": admin.id,
        "username": admin.username,
        "email": admin.email,
        "full_name": admin.full_name,
        "role": admin.role
    }

    return ApiResponse(
        success=True,
        data={
            "access_token": access_token,
            "token_type": "bearer",
            "admin": admin_data
        },
        message="Login successful."
    )

@router.get("/me", response_model=ApiResponse)
def get_me(admin: Admin = Depends(get_current_admin)):
    return ApiResponse(
        success=True,
        data={
            "id": admin.id,
            "username": admin.username,
            "email": admin.email,
            "full_name": admin.full_name,
            "role": admin.role,
            "is_active": admin.is_active,
            "created_at": admin.created_at.isoformat()
        },
        message="Profile retrieved."
    )

@router.post("/change-password", response_model=ApiResponse)
def change_password(
    req: ChangePasswordRequest,
    admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    if not verify_password(req.old_password, admin.password_hash):
        raise HTTPException(status_code=400, detail="Current password is incorrect.")
    
    if len(req.new_password) < 6:
        raise HTTPException(status_code=400, detail="New password must be at least 6 characters.")

    admin.password_hash = get_password_hash(req.new_password)
    
    audit = AuditLog(
        admin_id=admin.id,
        admin_name=admin.full_name,
        action="CHANGE_PASSWORD",
        entity_type="Admin",
        entity_id=str(admin.id),
        old_data=None,
        new_data="Password updated"
    )
    db.add(audit)
    db.commit()

    return ApiResponse(success=True, message="Password updated successfully.")

@router.post("/reset-password", response_model=ApiResponse)
def reset_password(req: ResetPasswordRequest, db: Session = Depends(get_db)):
    email = req.email.strip().lower()
    if len(req.new_password) < 6:
        raise HTTPException(status_code=400, detail="New password must be at least 6 characters.")

    admin = db.query(Admin).filter(
        (Admin.email.ilike(email)) | (Admin.username.ilike(email))
    ).first()

    if not admin:
        raise HTTPException(status_code=404, detail=f"No account found with email or username '{email}'.")

    admin.password_hash = get_password_hash(req.new_password)

    audit = AuditLog(
        admin_id=admin.id,
        admin_name=admin.full_name,
        action="RESET_PASSWORD",
        entity_type="Admin",
        entity_id=str(admin.id),
        old_data=None,
        new_data=f"Password reset for {admin.email}"
    )
    db.add(audit)
    db.commit()
    db.refresh(admin)

    access_token = create_access_token(
        data={"sub": str(admin.id), "email": admin.email, "role": admin.role}
    )

    admin_data = {
        "id": admin.id,
        "username": admin.username,
        "email": admin.email,
        "full_name": admin.full_name,
        "role": admin.role
    }

    return ApiResponse(
        success=True,
        data={
            "access_token": access_token,
            "token_type": "bearer",
            "admin": admin_data
        },
        message=f"Password updated successfully! Welcome back, {admin.full_name}."
    )

@router.get("/users", response_model=ApiResponse)
def list_users(
    admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    users = db.query(Admin).order_by(Admin.id.asc()).all()
    user_list = [
        {
            "id": u.id,
            "username": u.username,
            "email": u.email,
            "full_name": u.full_name,
            "role": u.role,
            "is_active": u.is_active,
            "created_at": u.created_at.isoformat() if u.created_at else None
        }
        for u in users
    ]
    return ApiResponse(
        success=True,
        data=user_list,
        message="User list retrieved."
    )

@router.post("/admin/reset-password", response_model=ApiResponse)
def admin_reset_password(
    req: AdminResetPasswordRequest,
    current_admin: Admin = Depends(require_super_admin),
    db: Session = Depends(get_db)
):
    email = req.target_email.strip().lower()
    if len(req.new_password) < 6:
        raise HTTPException(status_code=400, detail="New password must be at least 6 characters.")

    target = db.query(Admin).filter(
        (Admin.email.ilike(email)) | (Admin.username.ilike(email))
    ).first()
    if not target:
        raise HTTPException(status_code=404, detail=f"User '{email}' not found.")

    target.password_hash = get_password_hash(req.new_password)
    audit = AuditLog(
        admin_id=current_admin.id,
        admin_name=current_admin.full_name,
        action="ADMIN_RESET_PASSWORD",
        entity_type="Admin",
        entity_id=str(target.id),
        new_data=f"SuperAdmin reset password for {target.email}"
    )
    db.add(audit)
    db.commit()
    return ApiResponse(
        success=True,
        message=f"Successfully reset password for {target.full_name} ({target.email})."
    )
