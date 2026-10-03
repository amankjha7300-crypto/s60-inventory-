import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.main import app
from app.database.session import Base, get_db
from app.database.seed import seed_database
from app.core.config import settings

# Test database
TEST_DB_URL = "sqlite:///./test_s60inventory.db"
test_engine = create_engine(TEST_DB_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)

@pytest.fixture(scope="session", autouse=True)
def setup_test_db():
    Base.metadata.drop_all(bind=test_engine)
    Base.metadata.create_all(bind=test_engine)
    
    # Override get_db
    def override_get_db():
        db = TestingSessionLocal()
        try:
            yield db
        finally:
            db.close()
            
    app.dependency_overrides[get_db] = override_get_db
    
    # Seed test database
    db = TestingSessionLocal()
    # Temporarily bind engine for seed
    from app.database import seed
    seed.engine = test_engine
    seed.SessionLocal = TestingSessionLocal
    seed.seed_database(force=True)
    db.close()

    yield

    Base.metadata.drop_all(bind=test_engine)

@pytest.fixture
def client():
    return TestClient(app)

@pytest.fixture
def admin_token(client):
    res = client.post("/api/v1/auth/login", json={
        "email": settings.DEFAULT_ADMIN_EMAIL,
        "password": settings.DEFAULT_ADMIN_PASSWORD
    })
    assert res.status_code == 200
    data = res.json()["data"]
    return data["access_token"]

@pytest.fixture
def auth_headers(admin_token):
    return {"Authorization": f"Bearer {admin_token}"}
