from seed import DEMO_USERS, seed


def test_seed_returns_generated_password_only_for_new_demo_users(monkeypatch, tmp_path):
    monkeypatch.setenv("DATABASE_PATH", str(tmp_path / "seed.db"))
    monkeypatch.setenv("SECRET_KEY", "seed-test-secret")

    generated_password = seed()
    assert isinstance(generated_password, str)
    assert len(generated_password) >= 12

    assert seed() is None
    assert len(DEMO_USERS) == 5
