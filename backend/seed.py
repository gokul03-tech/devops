"""Create a small, repeatable demonstration dataset with a generated password."""
import secrets
from werkzeug.security import generate_password_hash

from app import Skill, User, UserSkill, create_app, db

SKILLS = ["Python", "JavaScript", "React", "Public Speaking", "Graphic Design", "Data Analysis", "Spanish", "Photography", "Guitar", "Academic Writing"]
DEMO_USERS = [
    ("Aarav Mehta", "aarav@example.edu", "Computer Science", "2", {"teach": ["Python", "Data Analysis"], "learn": ["Guitar"]}),
    ("Mia Chen", "mia@example.edu", "Computer Science", "3", {"teach": ["React", "JavaScript"], "learn": ["Python"]}),
    ("Noah Patel", "noah@example.edu", "Design", "2", {"teach": ["Graphic Design", "Photography"], "learn": ["Public Speaking"]}),
    ("Sofia Garcia", "sofia@example.edu", "Languages", "4", {"teach": ["Spanish", "Public Speaking"], "learn": ["Graphic Design"]}),
    ("Ethan Brooks", "ethan@example.edu", "Computer Science", "1", {"teach": ["Guitar", "Academic Writing"], "learn": ["JavaScript"]}),
]


def seed():
    app = create_app()
    demo_password = secrets.token_urlsafe(12)
    with app.app_context():
        db.create_all()
        skills = {}
        for name in SKILLS:
            skill = Skill.query.filter_by(skill_name=name).first()
            if not skill:
                skill = Skill(skill_name=name, category="General")
                db.session.add(skill)
            skills[name] = skill
        db.session.flush()
        created_users = False
        for name, email, department, year, interests in DEMO_USERS:
            user = User.query.filter_by(email=email).first()
            if not user:
                created_users = True
                user = User(name=name, email=email, password_hash=generate_password_hash(demo_password), department=department, year=year, availability="Weekday evenings,Weekends")
                db.session.add(user)
                db.session.flush()
            for kind, names in interests.items():
                for skill_name in names:
                    key = (user.id, skills[skill_name].id, kind)
                    if not db.session.get(UserSkill, key):
                        db.session.add(UserSkill(user_id=user.id, skill_id=skills[skill_name].id, skill_type=kind))
        db.session.commit()
    return (demo_password if created_users else None)


if __name__ == "__main__":
    generated_password = seed()
    if generated_password:
        print(f"Seeded PeerLearn demo data. Generated password for newly created demo users: {generated_password}")
    else:
        print("Demo users already exist; their passwords were left unchanged.")
