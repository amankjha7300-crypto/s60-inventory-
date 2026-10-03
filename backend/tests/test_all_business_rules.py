import pytest
from app.core.config import settings

def test_login_success(client):
    res = client.post("/api/v1/auth/login", json={
        "email": settings.DEFAULT_ADMIN_EMAIL,
        "password": settings.DEFAULT_ADMIN_PASSWORD
    })
    assert res.status_code == 200
    data = res.json()
    assert data["success"] is True
    assert "access_token" in data["data"]
    assert data["data"]["admin"]["email"] == settings.DEFAULT_ADMIN_EMAIL

def test_login_invalid_password(client):
    res = client.post("/api/v1/auth/login", json={
        "email": settings.DEFAULT_ADMIN_EMAIL,
        "password": "WrongPassword123"
    })
    assert res.status_code == 401

def test_dashboard_live_statistics(client, auth_headers):
    res = client.get("/api/v1/dashboard", headers=auth_headers)
    assert res.status_code == 200
    data = res.json()["data"]
    assert data["active_students_count"] >= 180
    assert data["total_events_count"] >= 4
    assert data["total_inventory_units"] > 0
    assert data["total_distributed_units"] > 0
    assert data["current_scheme"] == "ODD"

def test_saved_events_search_and_filter(client, auth_headers):
    # Test search by name
    res = client.get("/api/v1/events?search=Coding", headers=auth_headers)
    assert res.status_code == 200
    items = res.json()["data"]["items"]
    assert len(items) >= 1
    assert "Coding" in items[0]["name"]
    assert "event_uid" in items[0]
    assert items[0]["event_uid"].startswith("S60-EVT-")

    # Test filter by status
    res = client.get("/api/v1/events?status=Completed", headers=auth_headers)
    assert res.status_code == 200
    for ev in res.json()["data"]["items"]:
        assert ev["status"].lower() == "completed"

def test_create_event_auto_uid(client, auth_headers):
    res = client.post("/api/v1/events", headers=auth_headers, json={
        "name": "Cloud Native Architecture Summit",
        "event_type": "Workshop",
        "description": "High performance computing seminar",
        "event_date": "20 Nov 2026",
        "event_time": "11:00 AM",
        "venue": "Hall A",
        "applicable_semesters": [3, 5, 7],
        "status": "Upcoming"
    })
    assert res.status_code == 200
    ev = res.json()["data"]
    assert ev["name"] == "Cloud Native Architecture Summit"
    assert ev["event_uid"].startswith("S60-EVT-")

def test_distribution_stock_deduction_and_insufficient_stock(client, auth_headers):
    # 1. Get an active event detail
    events_res = client.get("/api/v1/events?search=Coding", headers=auth_headers)
    ev_id = events_res.json()["data"]["items"][0]["id"]
    ev_detail = client.get(f"/api/v1/events/{ev_id}", headers=auth_headers).json()["data"]

    # Pick an inventory item
    inv_item = [i for i in ev_detail["inventories"] if i["item_name"] == "T-Shirt"][0]
    ev_inv_id = inv_item["id"]
    initial_remaining = inv_item["remaining_quantity"]

    # Pick a student who has not received it (e.g. S60-055)
    st_res = client.get("/api/v1/students?search=S60-055", headers=auth_headers)
    st_id = st_res.json()["data"]["items"][0]["id"]

    # 2. Record distribution of 1 unit
    dist_res = client.post("/api/v1/distribution/save", headers=auth_headers, json={
        "student_id": st_id,
        "event_inventory_id": ev_inv_id,
        "quantity": 1,
        "remarks": "Test distribution"
    })
    assert dist_res.status_code == 200
    assert dist_res.json()["data"]["remaining_quantity"] == initial_remaining - 1

    # 3. Duplicate distribution test: attempting to distribute again must be rejected!
    dup_res = client.post("/api/v1/distribution/save", headers=auth_headers, json={
        "student_id": st_id,
        "event_inventory_id": ev_inv_id,
        "quantity": 1
    })
    assert dup_res.status_code == 400
    assert "already received" in dup_res.json()["detail"].lower()

    # 4. Insufficient stock test: attempt to distribute 9999 units must be rejected
    st_res_other = client.get("/api/v1/students?search=S60-056", headers=auth_headers)
    st_other_id = st_res_other.json()["data"]["items"][0]["id"]
    over_res = client.post("/api/v1/distribution/save", headers=auth_headers, json={
        "student_id": st_other_id,
        "event_inventory_id": ev_inv_id,
        "quantity": 9999
    })
    assert over_res.status_code == 400
    assert "insufficient" in over_res.json()["detail"].lower()

def test_distribution_reversal_undo(client, auth_headers):
    # Find student S60-055's recent distribution
    st_res = client.get("/api/v1/students?search=S60-055", headers=auth_headers)
    st = st_res.json()["data"]["items"][0]
    profile = client.get(f"/api/v1/students/{st['id']}", headers=auth_headers).json()["data"]
    
    assert len(profile["reward_history"]) > 0
    dist_id = profile["reward_history"][0]["distribution_id"]

    # Reverse distribution
    rev_res = client.post(f"/api/v1/distribution/{dist_id}/reverse", headers=auth_headers)
    assert rev_res.status_code == 200
    assert rev_res.json()["data"]["status"] == "CANCELLED"

def test_student_deactivate_preserves_reward_history(client, auth_headers):
    # Student S60-001 has history
    st_res = client.get("/api/v1/students?search=S60-001", headers=auth_headers)
    st = st_res.json()["data"]["items"][0]
    st_id = st["id"]

    # Try hard delete -> must fail because historical records exist
    del_res = client.delete(f"/api/v1/students/{st_id}", headers=auth_headers)
    assert del_res.status_code == 400
    assert "deactivate" in del_res.json()["detail"].lower()

    # Deactivate student -> succeeds
    deact_res = client.post(f"/api/v1/students/{st_id}/deactivate", headers=auth_headers)
    assert deact_res.status_code == 200

    # Profile should still show reward history!
    prof = client.get(f"/api/v1/students/{st_id}", headers=auth_headers).json()["data"]
    assert prof["student"]["status"] == "INACTIVE"
    assert len(prof["reward_history"]) > 0

def test_academic_session_promotion_preserves_student_ids(client, auth_headers):
    # Current session
    curr = client.get("/api/v1/academic-sessions/current", headers=auth_headers).json()["data"]
    assert curr["current_scheme"] == "ODD"

    # Preview promotion
    preview = client.get(f"/api/v1/academic-sessions/{curr['id']}/promote-preview", headers=auth_headers).json()["data"]
    assert preview["scheme_from"] == "ODD"
    assert preview["scheme_to"] == "EVEN"
    assert "3rd → 4th Semester" in preview["transitions"]

    # Student Anurag S60-002 initial semester
    anurag_before = client.get("/api/v1/students?search=S60-002", headers=auth_headers).json()["data"]["items"][0]
    assert anurag_before["current_semester"] == 3

    # Execute Promotion
    promote_res = client.post(f"/api/v1/academic-sessions/{curr['id']}/promote", headers=auth_headers)
    assert promote_res.status_code == 200
    assert promote_res.json()["data"]["new_scheme"] == "EVEN"

    # Anurag S60-002 must now be in semester 4, but student_id remains S60-002!
    anurag_after = client.get("/api/v1/students?search=S60-002", headers=auth_headers).json()["data"]["items"][0]
    assert anurag_after["student_id"] == "S60-002"
    assert anurag_after["current_semester"] == 4

    # Reward history must still show original semester snapshot!
    anurag_prof = client.get(f"/api/v1/students/{anurag_after['id']}", headers=auth_headers).json()["data"]
    for rew in anurag_prof["reward_history"]:
        assert rew["semester_at_distribution"] == 3  # Historical snapshot preserved!


def test_export_csv(client, auth_headers):
    res = client.get("/api/v1/reports/export-csv?report_type=distribution", headers=auth_headers)
    assert res.status_code == 200
    assert "text/csv" in res.headers["content-type"]
    assert "Student ID,Roll Number,Student Name" in res.text
