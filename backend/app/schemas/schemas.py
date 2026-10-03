from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List, Any, Dict
from datetime import datetime

# --- Common Response Wrapper ---
class ApiResponse(BaseModel):
    success: bool
    data: Optional[Any] = None
    message: str = ""

# --- Auth Schemas ---
class LoginRequest(BaseModel):
    email: str
    password: str

class SignUpRequest(BaseModel):
    full_name: str
    email: str
    username: Optional[str] = None
    role: str = "COORDINATOR"
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    admin: Dict[str, Any]

class AdminResponse(BaseModel):
    id: int
    username: str
    email: str
    full_name: str
    role: str
    is_active: bool

# --- Academic Session Schemas ---
class AcademicSessionCreate(BaseModel):
    session_name: str  # e.g., "2026-27"
    current_scheme: str = "ODD"  # ODD or EVEN
    is_active: bool = True

class AcademicSessionUpdate(BaseModel):
    session_name: Optional[str] = None
    current_scheme: Optional[str] = None
    is_active: Optional[bool] = None

class AcademicSessionResponse(BaseModel):
    id: int
    session_name: str
    current_scheme: str
    is_active: bool
    active_semesters: List[int]
    created_at: datetime

    class Config:
        from_attributes = True

class PromotionConfirmRequest(BaseModel):
    academic_session_id: int
    target_scheme: str  # "ODD" or "EVEN"
    promote_graduated: bool = True

class PromotionPreview(BaseModel):
    total_eligible: int
    transitions: Dict[str, int]  # e.g. {"3->4": 60, "5->6": 60, "7->8": 60}
    scheme_from: str
    scheme_to: str

# --- Student Schemas ---
class StudentCreate(BaseModel):
    student_id: str  # "S60-001"
    roll_number: str  # "23CSE001"
    name: str
    email: Optional[str] = None
    phone: Optional[str] = None
    branch: str = "CSE"
    batch: str = "2025"
    current_semester: int
    academic_session_id: Optional[int] = None
    status: str = "ACTIVE"

class StudentUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    branch: Optional[str] = None
    batch: Optional[str] = None
    current_semester: Optional[int] = None
    status: Optional[str] = None

class StudentResponse(BaseModel):
    id: int
    student_id: str
    roll_number: str
    name: str
    email: Optional[str] = None
    phone: Optional[str] = None
    branch: str
    batch: str
    current_semester: int
    status: str
    academic_session_id: Optional[int] = None
    created_at: datetime

    class Config:
        from_attributes = True

class BulkImportStudentItem(BaseModel):
    student_id: str
    name: str
    roll_number: str
    email: Optional[str] = None
    phone: Optional[str] = None
    batch: Optional[str] = "2025"
    semester: int

class BulkImportResult(BaseModel):
    imported_count: int
    skipped_count: int
    errors: List[str]

# --- Inventory Schemas ---
class InventoryItemCreate(BaseModel):
    name: str
    category: str = "Other"
    unit: str = "units"
    description: Optional[str] = None
    default_sku: Optional[str] = None

class InventoryItemResponse(BaseModel):
    id: int
    name: str
    category: str
    unit: str
    description: Optional[str] = None
    default_sku: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True

class EventInventoryCreate(BaseModel):
    inventory_item_id: int
    initial_quantity: int = Field(gt=0, description="Quantity must be greater than 0")
    eligibility_type: str = "ALL"  # ALL, SEMESTER, SELECTED, WINNERS
    semester_filter: Optional[int] = None
    low_stock_threshold: int = 10

class EventInventoryUpdate(BaseModel):
    initial_quantity: Optional[int] = None
    eligibility_type: Optional[str] = None
    semester_filter: Optional[int] = None
    low_stock_threshold: Optional[int] = None

class EventInventoryResponse(BaseModel):
    id: int
    event_id: int
    inventory_item_id: int
    item_name: str
    category: str
    unit: str
    initial_quantity: int
    distributed_quantity: int
    remaining_quantity: int
    eligibility_type: str
    semester_filter: Optional[int] = None
    low_stock_threshold: int
    status: str  # "Available", "Low Stock", "Out of Stock"

# --- Winner Schemas ---
class WinnerCreate(BaseModel):
    student_id: int
    position: str  # "1st Position", "2nd Position", "3rd Position", "Runner Up"
    prize_title: Optional[str] = None
    notes: Optional[str] = None

class WinnerResponse(BaseModel):
    id: int
    student_id: int
    student_uid: str
    student_name: str
    student_roll: str
    position: str
    prize_title: Optional[str] = None
    notes: Optional[str] = None

# --- Event Schemas ---
class EventCreate(BaseModel):
    name: str
    event_type: str  # Workshop, Seminar, Competition, Hackathon, etc.
    description: Optional[str] = None
    event_date: str  # "15 Oct 2026" or "2026-10-15"
    event_time: Optional[str] = None
    venue: Optional[str] = None
    academic_session_id: Optional[int] = None
    semester_scheme: str = "ODD"
    applicable_semesters: List[int] = [3, 5, 7]
    status: str = "Upcoming"
    initial_items: Optional[List[EventInventoryCreate]] = None

class EventUpdate(BaseModel):
    name: Optional[str] = None
    event_type: Optional[str] = None
    description: Optional[str] = None
    event_date: Optional[str] = None
    event_time: Optional[str] = None
    venue: Optional[str] = None
    status: Optional[str] = None
    applicable_semesters: Optional[List[int]] = None

class EventListItemResponse(BaseModel):
    id: int
    event_uid: str
    name: str
    event_type: str
    event_date: str
    event_time: Optional[str] = None
    venue: Optional[str] = None
    status: str
    semester_scheme: str
    applicable_semesters: List[int]
    total_participants: int
    total_inventory_items: int
    total_quantity: int
    distributed_quantity: int
    remaining_quantity: int
    distribution_percentage: float

class EventDetailResponse(BaseModel):
    id: int
    event_uid: str
    name: str
    event_type: str
    description: Optional[str] = None
    event_date: str
    event_time: Optional[str] = None
    venue: Optional[str] = None
    status: str
    academic_session_name: Optional[str] = None
    semester_scheme: str
    applicable_semesters: List[int]
    inventories: List[EventInventoryResponse]
    winners: List[WinnerResponse]
    participants_count: int
    distributed_count: int
    total_quantity: int
    remaining_quantity: int
    created_at: datetime

# --- Distribution Schemas ---
class DistributionSaveItem(BaseModel):
    student_id: int
    event_inventory_id: int
    quantity: int = 1
    remarks: Optional[str] = None

class BatchDistributionRequest(BaseModel):
    event_id: int
    distributions: List[DistributionSaveItem]

class DistributionRecordResponse(BaseModel):
    id: int
    event_id: int
    event_name: str
    student_id: int
    student_uid: str
    student_name: str
    student_roll: str
    inventory_item_id: int
    item_name: str
    quantity: int
    status: str
    distributed_at: datetime
    distributed_by_name: str
    semester_at_distribution: int
    session_at_distribution: str
    remarks: Optional[str] = None

# Distribution Matrix for Event View
class StudentDistributionRow(BaseModel):
    student_id: int
    student_uid: str
    name: str
    roll_number: str
    semester: int
    is_winner: bool
    winner_position: Optional[str] = None
    items: Dict[int, Dict[str, Any]]  # event_inventory_id -> {eligible: bool, distributed: bool, quantity: int, distribution_id: Optional[int]}
    total_eligible: int
    total_received: int
    status: str  # "COMPLETED", "PARTIAL", "PENDING"

# --- Student Profile & History ---
class StudentRewardItem(BaseModel):
    distribution_id: int
    event_id: int
    event_name: str
    event_date: str
    item_name: str
    category: str
    quantity: int
    semester_at_distribution: int
    session_at_distribution: str
    distributed_at: datetime
    distributed_by: str

class StudentProfileDetail(BaseModel):
    student: StudentResponse
    reward_history: List[StudentRewardItem]
    wins: List[WinnerResponse]
    total_rewards_received: int
    total_events_attended: int

# --- Dashboard & Report Schemas ---
class DashboardOverview(BaseModel):
    academic_session_name: str
    current_scheme: str
    active_semesters: List[int]
    active_students_count: int
    active_events_count: int
    total_events_count: int
    total_inventory_units: int
    total_distributed_units: int
    total_pending_units: int
    recent_events: List[EventListItemResponse]
    low_stock_alerts: List[Dict[str, Any]]
    recent_distributions: List[DistributionRecordResponse]
