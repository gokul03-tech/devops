from app import create_app


def test_environment_config_prefers_secret_key_and_database_path(monkeypatch):
    monkeypatch.delenv("DATABASE_URL", raising=False)
    monkeypatch.setenv("DATABASE_PATH", "configured-peerlearn.db")
    monkeypatch.setenv("SECRET_KEY", "preferred-secret")
    monkeypatch.setenv("JWT_SECRET", "legacy-secret")

    app = create_app()

    assert app.config["SECRET_KEY"] == "preferred-secret"
    assert app.config["SQLALCHEMY_DATABASE_URI"] == "sqlite:///configured-peerlearn.db"


def test_legacy_jwt_secret_remains_supported(monkeypatch):
    monkeypatch.delenv("SECRET_KEY", raising=False)
    monkeypatch.delenv("DATABASE_URL", raising=False)
    monkeypatch.setenv("JWT_SECRET", "legacy-secret")

    assert create_app().config["SECRET_KEY"] == "legacy-secret"
