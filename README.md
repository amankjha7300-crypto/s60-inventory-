# S60 Inventory & Rewards Management System
### Super60 / Department of Computer Science & Engineering
**Swami Vivekanand Group of Institutes (SVIET)**

---

## 1. Project Overview
The **S60 Inventory & Rewards Management System** is a dedicated internal management portal and mobile application engineered for the Super60 department of SVIET. It provides an event-agnostic, generic management system to maintain student records, academic semester schemes (Odd/Even), create and track events, allocate inventory/reward items, determine eligibility, record winners, atomically track distributions, calculate remaining stock in real-time, preserve historical context across semester promotions, and generate management reports with CSV export.

> **CRITICAL ARCHITECTURAL BOUNDARY:**
> - **Management-Only in Version 1**: There is NO student-facing login, student app, or automatic external messaging (push, WhatsApp, email) in this release.
> - **Save Logic & Isolation**: Marking a reward distributed saves ONLY inside the internal Super60 management database atomically.
> - **Preserved History**: Promoting students (e.g., 3rd → 4th, 5th → 6th, 7th → 8th) retains the immutable historical reward snapshots. Student IDs are never duplicated.

---

## 2. Technology Stack & Architecture

```
                  SUPER60 MANAGEMENT
                          │
          ┌───────────────┴───────────────┐
          ▼                               ▼
  Flutter Android App             Web Management Portal
  (mobile/lib/...)                (http://localhost:8000/portal/)
          │                               │
          └───────────────┬───────────────┘
                          │ HTTPS / REST API (/api/v1)
                          ▼
                   FastAPI Backend
                   (backend/app/...)
                          │
                          ▼
               PostgreSQL / SQLite Database
        ┌─────────────────┼─────────────────┐
        ▼                 ▼                 ▼
     Students           Events          Inventory
  (180 Seeded)      (Saved Events)     (Real-time Stock)
                          │
                          ▼
                 Distribution Records
             (Atomic Ledger & Audit Log)
```

- **Mobile Client**: Flutter + Dart (`/mobile`) with clean architecture, Material 3, Google Fonts (Poppins), and Android release configuration.
- **Web Management Client**: Live Responsive Web Portal (`/web`) served directly at `http://localhost:8000/portal/`.
- **Backend**: FastAPI (Python 3.14) with REST APIs, JWT authentication, bcrypt password hashing, and OpenAPI documentation (`/docs`).
- **Database Engine**: SQLAlchemy 2.0 with PostgreSQL driver + zero-config local SQLite fallback (`s60inventory.db`).
- **Brand Identity**: Primary Orange (`#F47B20`), Primary Navy (`#0F2B5B`), Background Cream (`#FFF8E8`), Poppins font, and official SVIET + S60 logos.

---

## 3. Project Directory Structure

```text
c:/Users/Aman Kumar/OneDrive/Desktop/s60inventory/
│
├── assets/                          # Extracted official brand assets & logos
│   ├── sviet_logo.png
│   ├── s60_logo.png
│   ├── s60_symbol.png
│   ├── sviet_campus.png
│   └── favicon.png
│
├── mobile/                          # Full Flutter Mobile Application
│   ├── lib/
│   │   ├── core/                   # Theme, Colors, API config, Constants
│   │   ├── models/                 # Dart entity models
│   │   ├── services/               # ApiService (Centralized HTTP client)
│   │   ├── providers/              # AppProvider (ChangeNotifier state)
│   │   ├── screens/                # All application screens
│   │   │   ├── splash_screen.dart  # Exact mockup match with campus photo
│   │   │   ├── login_screen.dart   # Secure admin login
│   │   │   ├── main_navigation_screen.dart # 5-tab Bottom Navigation
│   │   │   ├── dashboard_screen.dart       # Live metrics & quick actions
│   │   │   ├── saved_events_screen.dart    # Saved Events & History
│   │   │   ├── event_detail_screen.dart    # Event tabs & inventory table
│   │   │   ├── create_event_screen.dart    # Event creation form
│   │   │   ├── distribution_screen.dart    # Checkbox distribution portal
│   │   │   ├── students_screen.dart        # Student database & reward timeline
│   │   │   ├── student_import_screen.dart  # Bulk CSV student upload
│   │   │   ├── reports_screen.dart         # Reports & CSV export trigger
│   │   │   └── settings_screen.dart        # Scheme toggle & promotion action
│   │   └── main.dart               # MultiProvider application root
│   ├── android/                    # Android Native Manifest & Gradle configs
│   └── pubspec.yaml
│
├── backend/                         # FastAPI Python Backend
│   ├── app/
│   │   ├── core/                   # Security, JWT, bcrypt, settings
│   │   ├── database/               # Engine, SessionLocal, Seed Data (180 students)
│   │   ├── models/                 # SQLAlchemy ORM database models
│   │   ├── schemas/                # Pydantic validation schemas
│   │   ├── api/v1/                 # Endpoints (Auth, Academic, Students, Events,
│   │   │                           #  Inventory, Distribution, Dashboard, Reports)
│   │   └── main.py                 # FastAPI application & router mounts
│   ├── tests/                      # Pytest suite verifying all 20+ business rules
│   ├── requirements.txt
│   ├── Dockerfile
│   └── .env.example
│
├── web/                             # Live Web Management Portal
│   ├── index.html                  # Single page app matching brand styleboard
│   ├── style.css                   # Custom CSS tokens
│   └── app.js                      # REST API client
│
├── docker-compose.yml
└── README.md
```

---

## 4. Key Business Logic & Implementation Highlights

### A. Academic Semester Scheme & Promotion
- **Odd Scheme**: Active semesters: **3rd, 5th, 7th**.
- **Even Scheme**: Active semesters: **4th, 6th, 8th**.
- **Promotion Flow (`POST /api/v1/academic-sessions/{id}/promote`)**:
  - `3rd → 4th`, `5th → 6th`, `7th → 8th` (Odd → Even).
  - `4th → 5th`, `6th → 7th`, `8th → COMPLETED / ALUMNI` (Even → Next Odd).
  - **Student ID is never changed** (e.g., `S60-001` remains `S60-001`).
  - Historical reward snapshots retain their `semester_at_distribution`.

### B. Atomic Distribution & Concurrency Protection
- **Checkbox Distribution**: Admin checks `T-Shirt ✓`, `Certificate ✓`, etc.
- **Stock Validation**: Rejects requests exceeding remaining stock (formula: `Remaining = Initial - Distributed`).
- **Duplicate Protection**: Prevents duplicate rewards for the same student and item unless explicitly edited/reversed.
- **Undo Distribution (`POST /api/v1/distribution/{id}/reverse`)**: Restores unit to inventory, adjusts counts, and records an audit log.

### C. Dedicated Saved Events / Event History
- Accessible under **Saved Events**.
- Searchable by Event Name, Event UID (`S60-EVT-XXXX`), Date, and Venue.
- Filterable by Scheme (Odd/Even), Semester (3..8), and Status (`Upcoming`, `Active`, `Completed`, `Archived`).

---

## 5. Development Credentials & API Endpoints

### Default Admin Account (Seeded on first startup):
- **Email / Username**: `admin@s60sviet.in`
- **Password**: `S60Admin@2026`
- **Role**: `SUPER_ADMIN`

### Active Local Endpoints:
- **Web Management Portal**: `http://localhost:8000/portal/`
- **Interactive Swagger Docs**: `http://localhost:8000/docs`
- **System Health Check**: `http://localhost:8000/health`
- **REST API v1**: `http://localhost:8000/api/v1/`

---

## 6. How to Run Locally

### 1. Backend Server
```powershell
cd backend
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### 2. Run Integration Tests
```powershell
cd backend
python -m pytest tests/ -v
```
*(All 10 integration tests verify authentication, student promotion, atomic distributions, duplicate rejection, and CSV reports).*

### 3. Open Web Management Portal
Navigate in your browser to:
[http://localhost:8000/portal/](http://localhost:8000/portal/)

---

## 7. Android APK Build Instructions

To build the release APK for Android using Flutter:

1. **Configure API Base URL**:
   In [mobile/lib/core/constants.dart](file:///c:/Users/Aman%20Kumar/OneDrive/Desktop/s60inventory/mobile/lib/core/constants.dart), set `defaultApiBaseUrl` to your production HTTPS URL or machine IP (e.g. `http://192.168.1.50:8000/api/v1`).
2. **Build Release APK**:
   ```bash
   cd mobile
   flutter pub get
   flutter build apk --release
   ```
3. The resulting installable APK will be generated at:
   `mobile/build/app/outputs/flutter-apk/app-release.apk`
