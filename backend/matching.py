"""Rule-based peer matching, kept independent for focused unit tests."""
from app import Skill, UserSkill, db


def find_matches(requester, skill_name, department=None):
    """Return eligible teachers ordered by mutual interest and availability overlap."""
    requested = Skill.query.filter(db.func.lower(Skill.skill_name) == skill_name.strip().lower()).first()
    if not requested:
        return []
    teachers = UserSkill.query.filter_by(skill_id=requested.id, skill_type="teach").all()
    requester_teaches = {row.skill_id for row in UserSkill.query.filter_by(user_id=requester.id, skill_type="teach").all()}
    requester_slots = {slot for slot in requester.availability.split(",") if slot}
    results = []
    for association in teachers:
        candidate = association.user
        if candidate.id == requester.id or (department and candidate.department.lower() != department.lower()):
            continue
        candidate_learns = {row.skill_id for row in UserSkill.query.filter_by(user_id=candidate.id, skill_type="learn").all()}
        mutual = bool(requester_teaches & candidate_learns)
        overlaps = len(requester_slots & {slot for slot in candidate.availability.split(",") if slot})
        same_department = bool(requester.department and candidate.department.lower() == requester.department.lower())
        score = (3 if mutual else 0) + overlaps + (1 if same_department else 0)
        results.append({"id": candidate.id, "name": candidate.name, "department": candidate.department,
                        "year": candidate.year, "availability": sorted({slot for slot in candidate.availability.split(",") if slot}),
                        "score": score, "match_type": "Mutual Exchange" if mutual else "Skill Match",
                        "teaches": requested.skill_name,
                        "learns": [row.skill.skill_name for row in candidate.skills if row.skill_type == "learn"]})
    return sorted(results, key=lambda match: (-match["score"], match["name"].lower(), match["id"]))
