import datetime
from sqlalchemy import (
    Column, Integer, String, Text, DateTime, Boolean, ForeignKey, Index
)
from sqlalchemy.orm import relationship
from app.database.session import Base

def utcnow():
    return datetime.datetime.now(datetime.timezone.utc)

class Admin(Base):
    __tablename__ = "admins"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, index=True, nullable=False)
    email = Column(String(120), unique=True, index=True, nullable=False)
    full_name = Column(String(100), nullable=False)
    password_hash = Column(String(255), nullable=False)
    role = Column(String(30), default="SUPER_ADMIN", nullable=False)  # SUPER_ADMIN, EVENT_MANAGER, INVENTORY_MANAGER, VIEWER
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)

    # Relationships
    distributions = relationship("Distribution", back_populates="admin_user", foreign_keys="Distribution.distributed_by_id")
    events_created = relationship("Event", back_populates="creator", foreign_keys="Event.created_by_id")


class AcademicSession(Base):
    __tablename__ = "academic_sessions"

    id = Column(Integer, primary_key=True, index=True)
    session_name = Column(String(20), unique=True, index=True, nullable=False)  # e.g., "2026-27"
    current_scheme = Column(String(10), default="ODD", nullable=False)  # ODD (3,5,7) or EVEN (4,6,8)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)

    # Relationships
    students = relationship("Student", back_populates="academic_session")
    events = relationship("Event", back_populates="academic_session")


class Student(Base):
    __tablename__ = "students"

    id = Column(Integer, primary_key=True, index=True)
    student_id = Column(String(50), unique=True, index=True, nullable=False)  # e.g., "S60-001"
    roll_number = Column(String(50), unique=True, index=True, nullable=False)  # e.g., "23CSE001"
    name = Column(String(100), index=True, nullable=False)
    email = Column(String(120), nullable=True)
    phone = Column(String(25), nullable=True)
    branch = Column(String(50), default="CSE", nullable=False)
    batch = Column(String(20), default="2025", nullable=False)
    current_semester = Column(Integer, index=True, nullable=False)  # 3, 4, 5, 6, 7, 8
    academic_session_id = Column(Integer, ForeignKey("academic_sessions.id"), nullable=True)
    status = Column(String(20), default="ACTIVE", index=True, nullable=False)  # ACTIVE, INACTIVE, COMPLETED
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)

    # Relationships
    academic_session = relationship("AcademicSession", back_populates="students")
    distributions = relationship("Distribution", back_populates="student", cascade="all, delete-orphan")
    participants = relationship("EventParticipant", back_populates="student", cascade="all, delete-orphan")
    wins = relationship("Winner", back_populates="student", cascade="all, delete-orphan")


class Event(Base):
    __tablename__ = "events"

    id = Column(Integer, primary_key=True, index=True)
    event_uid = Column(String(50), unique=True, index=True, nullable=False)  # e.g., "S60-EVT-0001"
    name = Column(String(150), index=True, nullable=False)
    event_type = Column(String(50), index=True, nullable=False)  # Workshop, Seminar, Competition, Hackathon, etc.
    description = Column(Text, nullable=True)
    event_date = Column(String(30), index=True, nullable=False)  # e.g., "2026-10-15" or "15 Oct 2026"
    event_time = Column(String(30), nullable=True)
    venue = Column(String(100), nullable=True)
    status = Column(String(30), default="Upcoming", index=True, nullable=False)  # Upcoming, Ongoing, Completed, Archived, Cancelled
    academic_session_id = Column(Integer, ForeignKey("academic_sessions.id"), nullable=True)
    semester_scheme = Column(String(10), default="ODD", nullable=False)  # ODD or EVEN
    applicable_semesters = Column(String(50), default="3,5,7", nullable=False)  # comma separated: "3,5,7" or "4,6,8"
    created_by_id = Column(Integer, ForeignKey("admins.id"), nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)

    # Relationships
    academic_session = relationship("AcademicSession", back_populates="events")
    creator = relationship("Admin", back_populates="events_created", foreign_keys=[created_by_id])
    event_inventories = relationship("EventInventory", back_populates="event", cascade="all, delete-orphan")
    participants = relationship("EventParticipant", back_populates="event", cascade="all, delete-orphan")
    winners = relationship("Winner", back_populates="event", cascade="all, delete-orphan")
    distributions = relationship("Distribution", back_populates="event", cascade="all, delete-orphan")


class EventParticipant(Base):
    __tablename__ = "event_participants"

    id = Column(Integer, primary_key=True, index=True)
    event_id = Column(Integer, ForeignKey("events.id"), nullable=False, index=True)
    student_id = Column(Integer, ForeignKey("students.id"), nullable=False, index=True)
    participation_status = Column(String(20), default="ATTENDED", nullable=False)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    event = relationship("Event", back_populates="participants")
    student = relationship("Student", back_populates="participants")


class InventoryItem(Base):
    __tablename__ = "inventory_items"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), index=True, nullable=False)  # e.g., "T-Shirt", "Notebook", "Certificate", "Trophy"
    category = Column(String(50), default="Other", index=True, nullable=False)  # Apparel, Stationery, Certificate, Award, Gift, Kit
    unit = Column(String(20), default="units", nullable=False)
    description = Column(Text, nullable=True)
    default_sku = Column(String(50), nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)

    event_allocations = relationship("EventInventory", back_populates="inventory_item")


class EventInventory(Base):
    __tablename__ = "event_inventory"

    id = Column(Integer, primary_key=True, index=True)
    event_id = Column(Integer, ForeignKey("events.id"), nullable=False, index=True)
    inventory_item_id = Column(Integer, ForeignKey("inventory_items.id"), nullable=False, index=True)
    initial_quantity = Column(Integer, default=0, nullable=False)
    distributed_quantity = Column(Integer, default=0, nullable=False)
    remaining_quantity = Column(Integer, default=0, nullable=False)
    eligibility_type = Column(String(30), default="ALL", nullable=False)  # ALL, SEMESTER, SELECTED, WINNERS
    semester_filter = Column(Integer, nullable=True)  # e.g. 3 or 5 or 7
    low_stock_threshold = Column(Integer, default=10, nullable=False)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)

    event = relationship("Event", back_populates="event_inventories")
    inventory_item = relationship("InventoryItem", back_populates="event_allocations")
    distributions = relationship("Distribution", back_populates="event_inventory", cascade="all, delete-orphan")


class Winner(Base):
    __tablename__ = "winners"

    id = Column(Integer, primary_key=True, index=True)
    event_id = Column(Integer, ForeignKey("events.id"), nullable=False, index=True)
    student_id = Column(Integer, ForeignKey("students.id"), nullable=False, index=True)
    position = Column(String(30), nullable=False)  # "1st Position", "2nd Position", "3rd Position"
    prize_title = Column(String(100), nullable=True)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    event = relationship("Event", back_populates="winners")
    student = relationship("Student", back_populates="wins")


class Distribution(Base):
    __tablename__ = "distributions"

    id = Column(Integer, primary_key=True, index=True)
    event_id = Column(Integer, ForeignKey("events.id"), nullable=False, index=True)
    student_id = Column(Integer, ForeignKey("students.id"), nullable=False, index=True)
    event_inventory_id = Column(Integer, ForeignKey("event_inventory.id"), nullable=False, index=True)
    quantity = Column(Integer, default=1, nullable=False)
    status = Column(String(20), default="DISTRIBUTED", index=True, nullable=False)  # DISTRIBUTED, PENDING, CANCELLED
    distributed_at = Column(DateTime, default=utcnow, nullable=False)
    distributed_by_id = Column(Integer, ForeignKey("admins.id"), nullable=True)
    distributed_by_name = Column(String(100), default="Management", nullable=False)
    semester_at_distribution = Column(Integer, nullable=False)  # Historical snapshot! (e.g. 3)
    session_at_distribution = Column(String(20), default="2026-27", nullable=False)  # Historical snapshot!
    remarks = Column(String(255), nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)

    # Relationships
    event = relationship("Event", back_populates="distributions")
    student = relationship("Student", back_populates="distributions")
    event_inventory = relationship("EventInventory", back_populates="distributions")
    admin_user = relationship("Admin", back_populates="distributions", foreign_keys=[distributed_by_id])

    __table_args__ = (
        Index("ix_dist_event_student_item", "event_id", "student_id", "event_inventory_id"),
    )


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id = Column(Integer, primary_key=True, index=True)
    admin_id = Column(Integer, nullable=True)
    admin_name = Column(String(100), default="Admin", nullable=False)
    action = Column(String(50), index=True, nullable=False)  # CREATE_EVENT, DISTRIBUTE_ITEM, REVERSE_DISTRIBUTION, PROMOTE_STUDENTS, etc.
    entity_type = Column(String(50), index=True, nullable=False)  # Event, Distribution, Student, Inventory
    entity_id = Column(String(50), nullable=True)
    old_data = Column(Text, nullable=True)
    new_data = Column(Text, nullable=True)
    timestamp = Column(DateTime, default=utcnow, index=True, nullable=False)
