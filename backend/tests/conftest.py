import pytest

from app import create_app, db


@pytest.fixture
def app():
    application = create_app({"TESTING": True, "SECRET_KEY": "test-secret", "SQLALCHEMY_DATABASE_URI": "sqlite:///:memory:"})
    with application.app_context():
        db.create_all()
        yield application
        db.session.remove()
        db.drop_all()


@pytest.fixture
def client(app):
    return app.test_client()


@pytest.fixture
def register(client):
    def _register(name, email):
        response = client.post("/api/auth/register", json={"name": name, "email": email, "password": "password123", "department": "CS"})
        assert response.status_code == 201
        return response.get_json()
    return _register


@pytest.fixture
def auth(client):
    def _auth(token):
        return {"Authorization": f"Bearer {token}"}
    return _auth
