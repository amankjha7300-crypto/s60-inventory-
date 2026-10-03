from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database.session import get_db, Base, engine
from app.models.all_models import Admin, AuditLog
from app.database.seed import seed_database
from app.schemas.schemas import ApiResponse
from app.api.deps import require_super_admin

router = APIRouter(prefix="/system", tags=["System Management"])

@router.post("/reset-clean", response_model=ApiResponse)
def reset_clean(
    db: Session = Depends(get_db),
    admin: Admin = Depends(require_super_admin)
):
    """
    Clears all dummy/test data and resets database to a completely clean state:
    0 students, 0 events, 0 distributions.
    """
    seed_database(force=True, include_demo=False)
    return ApiResponse(
        success=True,
        message="Database reset to clean slate. All dummy data cleared. Ready for your actual student and event entries."
    )
