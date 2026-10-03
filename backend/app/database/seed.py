import datetime
from sqlalchemy.orm import Session
from app.database.session import SessionLocal, Base, engine
from app.models.all_models import (
    Admin, AcademicSession, Student, Event, EventParticipant,
    InventoryItem, EventInventory, Winner, Distribution, AuditLog
)
from app.core.security import get_password_hash
from app.core.config import settings

def utcnow():
    return datetime.datetime.now(datetime.timezone.utc)

def seed_database(force: bool = False, include_demo: bool = False):
    """
    Initializes a CLEAN production-ready database by default:
    - SuperAdmin account
    - Academic Session (2026-27, ODD Scheme: 3, 5, 7)
    - Clean slate for Students (NO pre-defined students)
    - Clean slate for Events (NO pre-defined events)
    - Clean slate for Distributions
    - Basic master inventory categories (optional, editable)
    """
    if force:
        Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    db: Session = SessionLocal()

    try:
        admin_exists = db.query(Admin).filter(Admin.email == settings.DEFAULT_ADMIN_EMAIL).first()
        if admin_exists and not force:
            print("Database already initialized.")
            return

        print("Initializing clean S60 Inventory & Rewards database...")

        # 1. Admin Account
        admin = Admin(
            username="s60admin",
            email=settings.DEFAULT_ADMIN_EMAIL,
            full_name=settings.DEFAULT_ADMIN_NAME,
            password_hash=get_password_hash(settings.DEFAULT_ADMIN_PASSWORD),
            role="SUPER_ADMIN",
            is_active=True
        )
        db.add(admin)
        db.commit()
        db.refresh(admin)

        # 2. Academic Session (2026-27, ODD Scheme: 3, 5, 7)
        session_2026 = AcademicSession(
            session_name="2026-27",
            current_scheme="ODD",
            is_active=True
        )
        db.add(session_2026)
        db.commit()
        db.refresh(session_2026)

        # 3. Clean database - zero predefined rewards/items, zero predefined students, zero predefined events.
        # Management will insert real data via Add Item and Insert Student options.
        db.add(AuditLog(
            admin_id=admin.id,
            admin_name=admin.full_name,
            action="SYSTEM_INIT",
            entity_type="System",
            entity_id="ROOT",
            new_data="Initialized 100% clean S60 Inventory & Rewards database (0 predefined students, 0 predefined events, 0 predefined rewards)."
        ))

        db.commit()
        print("Clean database ready! 0 predefined students, 0 predefined events, 0 predefined rewards.")

    except Exception as e:
        db.rollback()
        print(f"Error initializing database: {e}")
        raise e
    finally:
        db.close()

if __name__ == "__main__":
    seed_database(force=True, include_demo=False)
