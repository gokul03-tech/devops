from app import Skill, User, UserSkill, db
from matching import find_matches


def test_mutual_match_priority_and_filters(app):
    with app.app_context():
        requested = Skill(skill_name="Python")
        give = Skill(skill_name="Design")
        db.session.add_all([requested, give])
        db.session.flush()
        asker = User(name="Asker", email="asker@example.edu", password_hash="x", department="CS", availability="Mon,Tue")
        mutual = User(name="Mutual", email="mutual@example.edu", password_hash="x", department="CS", availability="Mon")
        regular = User(name="Regular", email="regular@example.edu", password_hash="x", department="Art", availability="Mon,Tue")
        db.session.add_all([asker, mutual, regular])
        db.session.flush()
        db.session.add_all([
            UserSkill(user_id=mutual.id, skill_id=requested.id, skill_type="teach"),
            UserSkill(user_id=mutual.id, skill_id=give.id, skill_type="learn"),
            UserSkill(user_id=asker.id, skill_id=give.id, skill_type="teach"),
            UserSkill(user_id=regular.id, skill_id=requested.id, skill_type="teach"),
        ])
        db.session.commit()
        matches = find_matches(asker, "Python")
        assert [item["name"] for item in matches] == ["Mutual", "Regular"]
        assert matches[0]["match_type"] == "Mutual Exchange"
        assert matches[0]["score"] > matches[1]["score"]
        assert find_matches(asker, "Python", "CS")[0]["name"] == "Mutual"
        assert find_matches(asker, "Unknown") == []
