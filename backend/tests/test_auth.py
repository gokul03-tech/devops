from app import User


def test_register_login_me_and_hash(client, register, auth, app):
    result = register("A", "a@example.edu")
    assert result["token"]
    with app.app_context():
        user = User.query.filter_by(email="a@example.edu").one()
        assert user.password_hash != "password123"
    assert client.get("/api/auth/me", headers=auth(result["token"])).get_json()["user"]["name"] == "A"
    assert client.post("/api/auth/login", json={"email": "a@example.edu", "password": "password123"}).status_code == 200


def test_registration_validation_duplicate_and_auth(client, register):
    assert client.post("/api/auth/register", json={"name": "A", "email": "bad", "password": "x"}).status_code == 400
    assert client.post("/api/auth/register", json={"name": [], "email": "a@example.edu", "password": "password123"}).status_code == 400
    register("A", "a@example.edu")
    assert client.post("/api/auth/register", json={"name": "A", "email": "a@example.edu", "password": "password123"}).status_code == 409
    assert client.get("/api/profile").status_code == 401
    assert client.post("/api/auth/login", json={"email": "a@example.edu", "password": "wrongpass"}).status_code == 401
    assert client.post("/api/auth/login", json={"email": [], "password": []}).status_code == 401
    assert client.get("/api/health").get_json() == {"status": "ok"}
