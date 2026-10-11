"""PeerLearn Flask API application factory."""
import os
from datetime import datetime, timedelta, timezone

import jwt
from flask import Flask, g, jsonify, request
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import check_password_hash, generate_password_hash

db = SQLAlchemy()


class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(120), nullable=False)
    email = db.Column(db.String(255), unique=True, nullable=False, index=True)
    password_hash = db.Column(db.String(255), nullable=False)
    department = db.Column(db.String(120), nullable=False, default="")
    year = db.Column(db.String(32), nullable=False, default="")
    availability = db.Column(db.Text, nullable=False, default="")
    skills = db.relationship("UserSkill", back_populates="user", cascade="all, delete-orphan")


class Skill(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    skill_name = db.Column(db.String(120), unique=True, nullable=False, index=True)
    category = db.Column(db.String(120), nullable=False, default="General")
    users = db.relationship("UserSkill", back_populates="skill", cascade="all, delete-orphan")


class UserSkill(db.Model):
    __tablename__ = "user_skills"
    user_id = db.Column(db.Integer, db.ForeignKey("user.id"), primary_key=True)
    skill_id = db.Column(db.Integer, db.ForeignKey("skill.id"), primary_key=True)
    skill_type = db.Column(db.String(8), primary_key=True)
    user = db.relationship("User", back_populates="skills")
    skill = db.relationship("Skill", back_populates="users")
    __table_args__ = (db.CheckConstraint("skill_type IN ('teach', 'learn')", name="ck_user_skill_type"),)


class SessionRequest(db.Model):
    __tablename__ = "session_requests"
    id = db.Column(db.Integer, primary_key=True)
    requester_id = db.Column(db.Integer, db.ForeignKey("user.id"), nullable=False)
    partner_id = db.Column(db.Integer, db.ForeignKey("user.id"), nullable=False)
    skill_id = db.Column(db.Integer, db.ForeignKey("skill.id"), nullable=False)
    proposed_time = db.Column(db.String(80), nullable=False)
    meeting_link = db.Column(db.String(500))
    status = db.Column(db.String(12), nullable=False, default="Pending")
    requester = db.relationship("User", foreign_keys=[requester_id])
    partner = db.relationship("User", foreign_keys=[partner_id])
    skill = db.relationship("Skill")
    reviews = db.relationship("Review", back_populates="session", cascade="all, delete-orphan")
    __table_args__ = (
        db.CheckConstraint("status IN ('Pending', 'Accepted', 'Rejected', 'Completed', 'Cancelled')", name="ck_session_status"),
    )


class Review(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    session_id = db.Column(db.Integer, db.ForeignKey("session_requests.id"), nullable=False)
    reviewer_id = db.Column(db.Integer, db.ForeignKey("user.id"), nullable=False)
    rating = db.Column(db.Integer, nullable=False)
    feedback = db.Column(db.Text, nullable=False, default="")
    session = db.relationship("SessionRequest", back_populates="reviews")
    reviewer = db.relationship("User")
    __table_args__ = (
        db.UniqueConstraint("session_id", "reviewer_id", name="uq_review_session_reviewer"),
        db.CheckConstraint("rating >= 1 AND rating <= 5", name="ck_review_rating"),
    )


def _json_error(message, status=400):
    return jsonify({"error": message}), status


def _availability(value):
    if not isinstance(value, list) or any(not isinstance(slot, str) or not slot.strip() for slot in value):
        raise ValueError("availability must be a list of non-empty time slots")
    return ",".join(dict.fromkeys(slot.strip() for slot in value))


def _user_json(user):
    return {"id": user.id, "name": user.name, "email": user.email,
            "department": user.department, "year": user.year,
            "availability": [s for s in user.availability.split(",") if s],
            "skills": [{"id": row.skill_id, "skill_name": row.skill.skill_name, "skill_type": row.skill_type} for row in user.skills]}


def create_app(test_config=None):
    app = Flask(__name__)
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        database_path = os.environ.get("DATABASE_PATH", "peerlearn.db")
        database_url = "sqlite:///" + database_path
    app.config.update(
        SECRET_KEY=os.environ.get("JWT_SECRET", "development-only-change-me"),
        SQLALCHEMY_DATABASE_URI=database_url,
        SQLALCHEMY_TRACK_MODIFICATIONS=False,
        JWT_EXPIRES_HOURS=24,
    )
    if test_config:
        app.config.update(test_config)
    db.init_app(app)
    CORS(app)

    @app.before_request
    def authenticate():
        if request.path in ("/api/health", "/api/auth/register", "/api/auth/login"):
            return
        header = request.headers.get("Authorization", "")
        if not header.startswith("Bearer "):
            return _json_error("Bearer token required", 401)
        try:
            payload = jwt.decode(header[7:], app.config["SECRET_KEY"], algorithms=["HS256"])
            g.user = db.session.get(User, int(payload.get("sub")))
            if not g.user:
                return _json_error("Invalid token", 401)
        except (jwt.InvalidTokenError, TypeError):
            return _json_error("Invalid token", 401)

    def token_for(user):
        return jwt.encode({"sub": str(user.id), "exp": datetime.now(timezone.utc) + timedelta(hours=app.config["JWT_EXPIRES_HOURS"])}, app.config["SECRET_KEY"], algorithm="HS256")

    @app.get("/api/health")
    def health():
        return jsonify(status="ok")

    @app.post("/api/auth/register")
    def register():
        data = request.get_json(silent=True) or {}
        name, email, password = data.get("name", "").strip(), data.get("email", "").strip().lower(), data.get("password", "")
        if not name or len(name) > 120 or "@" not in email or len(password) < 8:
            return _json_error("name, valid email and password (at least 8 characters) are required")
        if User.query.filter_by(email=email).first():
            return _json_error("email is already registered", 409)
        user = User(name=name, email=email, password_hash=generate_password_hash(password),
                    department=str(data.get("department", "")).strip(), year=str(data.get("year", "")).strip())
        db.session.add(user)
        db.session.commit()
        return jsonify(token=token_for(user), user=_user_json(user)), 201

    @app.post("/api/auth/login")
    def login():
        data = request.get_json(silent=True) or {}
        user = User.query.filter_by(email=str(data.get("email", "")).strip().lower()).first()
        if not user or not check_password_hash(user.password_hash, data.get("password", "")):
            return _json_error("invalid email or password", 401)
        return jsonify(token=token_for(user), user=_user_json(user))

    @app.get("/api/auth/me")
    def me():
        return jsonify(user=_user_json(g.user))

    @app.route("/api/profile", methods=["GET", "PUT"])
    def profile():
        if request.method == "GET":
            return jsonify(user=_user_json(g.user))
        data = request.get_json(silent=True) or {}
        for key in ("department", "year"):
            if key in data:
                if not isinstance(data[key], str) or len(data[key]) > 120:
                    return _json_error(f"{key} must be a string of at most 120 characters")
                setattr(g.user, key, data[key].strip())
        if "availability" in data:
            try:
                g.user.availability = _availability(data["availability"])
            except ValueError as exc:
                return _json_error(str(exc))
        db.session.commit()
        return jsonify(user=_user_json(g.user))

    @app.get("/api/skills")
    def skills():
        return jsonify(skills=[{"id": s.id, "skill_name": s.skill_name, "category": s.category} for s in Skill.query.order_by(Skill.skill_name).all()])

    @app.post("/api/profile/skills")
    def add_skill():
        data = request.get_json(silent=True) or {}
        name, skill_type = data.get("skill_name", ""), data.get("skill_type", "")
        if not isinstance(name, str) or not name.strip() or len(name.strip()) > 120:
            return _json_error("skill_name is required and must be at most 120 characters")
        if skill_type not in ("teach", "learn"):
            return _json_error("skill_type must be teach or learn")
        skill = Skill.query.filter(db.func.lower(Skill.skill_name) == name.strip().lower()).first()
        if not skill:
            skill = Skill(skill_name=name.strip(), category=str(data.get("category", "General"))[:120])
            db.session.add(skill)
            db.session.flush()
        existing = db.session.get(UserSkill, (g.user.id, skill.id, skill_type))
        if not existing:
            db.session.add(UserSkill(user_id=g.user.id, skill_id=skill.id, skill_type=skill_type))
            db.session.commit()
        return jsonify(skill={"id": skill.id, "skill_name": skill.skill_name, "skill_type": skill_type}), 201

    @app.delete("/api/profile/skills/<int:skill_id>")
    def remove_skill(skill_id):
        skill_type = request.args.get("type")
        if skill_type not in ("teach", "learn"):
            return _json_error("type query parameter must be teach or learn")
        association = db.session.get(UserSkill, (g.user.id, skill_id, skill_type))
        if not association:
            return _json_error("skill not found on profile", 404)
        db.session.delete(association)
        db.session.commit()
        return "", 204

    @app.get("/api/matches")
    def matches():
        from matching import find_matches
        skill_name = request.args.get("skill", "").strip()
        if not skill_name:
            return _json_error("skill query parameter is required")
        results = find_matches(g.user, skill_name, request.args.get("department"))
        return jsonify(matches=results)

    def session_json(session):
        return {"id": session.id, "requester_id": session.requester_id, "requester_name": session.requester.name,
                "partner_id": session.partner_id, "partner_name": session.partner.name, "skill_id": session.skill_id,
                "skill_name": session.skill.skill_name, "proposed_time": session.proposed_time,
                "meeting_link": session.meeting_link, "status": session.status}

    @app.route("/api/sessions", methods=["GET", "POST"])
    def sessions():
        if request.method == "GET":
            rows = SessionRequest.query.filter(db.or_(SessionRequest.requester_id == g.user.id, SessionRequest.partner_id == g.user.id)).order_by(SessionRequest.id.desc()).all()
            return jsonify(sessions=[session_json(s) for s in rows])
        data = request.get_json(silent=True) or {}
        try:
            partner_id, skill_id = int(data.get("partner_id")), int(data.get("skill_id"))
        except (TypeError, ValueError):
            return _json_error("partner_id and skill_id must be integers")
        partner = db.session.get(User, partner_id)
        skill = db.session.get(Skill, skill_id)
        if not partner or partner.id == g.user.id or not skill or not isinstance(data.get("proposed_time"), str) or not data["proposed_time"].strip():
            return _json_error("valid partner, skill and proposed_time are required")
        if not UserSkill.query.filter_by(user_id=partner.id, skill_id=skill.id, skill_type="teach").first():
            return _json_error("partner does not teach this skill")
        session = SessionRequest(requester_id=g.user.id, partner_id=partner.id, skill_id=skill.id,
                                 proposed_time=data["proposed_time"].strip(), meeting_link=data.get("meeting_link"))
        db.session.add(session)
        db.session.commit()
        return jsonify(session=session_json(session)), 201

    @app.patch("/api/sessions/<int:session_id>")
    def update_session(session_id):
        session = db.session.get(SessionRequest, session_id)
        if not session:
            return _json_error("session not found", 404)
        if g.user.id not in (session.requester_id, session.partner_id):
            return _json_error("only session participants can modify it", 403)
        data = request.get_json(silent=True) or {}
        action = data.get("action")
        transitions = {"accept": ("Pending", "Accepted", session.partner_id), "reject": ("Pending", "Rejected", session.partner_id),
                       "cancel": (("Pending", "Accepted"), "Cancelled", None), "complete": ("Accepted", "Completed", None)}
        if action not in transitions:
            return _json_error("action must be accept, reject, cancel or complete")
        required, target, actor = transitions[action]
        if actor and actor != g.user.id:
            return _json_error("only the invited partner can accept or reject", 403)
        if isinstance(required, tuple):
            allowed = session.status in required
        else:
            allowed = session.status == required
        if not allowed:
            return _json_error(f"cannot {action} a {session.status.lower()} session", 409)
        if action == "complete" and g.user.id not in (session.requester_id, session.partner_id):
            return _json_error("only session participants can complete it", 403)
        session.status = target
        if "meeting_link" in data:
            session.meeting_link = data["meeting_link"]
        db.session.commit()
        return jsonify(session=session_json(session))

    @app.post("/api/sessions/<int:session_id>/review")
    def review_session(session_id):
        session = db.session.get(SessionRequest, session_id)
        if not session:
            return _json_error("session not found", 404)
        if session.status != "Completed" or g.user.id not in (session.requester_id, session.partner_id):
            return _json_error("only participants can review a completed session", 403)
        data = request.get_json(silent=True) or {}
        rating = data.get("rating")
        if not isinstance(rating, int) or isinstance(rating, bool) or not 1 <= rating <= 5:
            return _json_error("rating must be an integer from 1 to 5")
        review = Review.query.filter_by(session_id=session.id, reviewer_id=g.user.id).first()
        if review:
            return _json_error("you have already reviewed this session", 409)
        review = Review(session_id=session.id, reviewer_id=g.user.id, rating=rating, feedback=str(data.get("feedback", ""))[:2000])
        db.session.add(review)
        db.session.commit()
        return jsonify(review={"id": review.id, "session_id": review.session_id, "reviewer_id": review.reviewer_id,
                              "rating": review.rating, "feedback": review.feedback}), 201

    @app.get("/api/history")
    def history():
        completed = SessionRequest.query.filter(SessionRequest.status == "Completed", db.or_(SessionRequest.requester_id == g.user.id, SessionRequest.partner_id == g.user.id)).all()
        result = []
        for session in completed:
            result.append({"session": session_json(session), "reviews": [{"reviewer_id": r.reviewer_id, "rating": r.rating, "feedback": r.feedback} for r in session.reviews]})
        return jsonify(history=result)

    @app.get("/api/dashboard")
    def dashboard():
        rows = SessionRequest.query.filter(db.or_(SessionRequest.requester_id == g.user.id, SessionRequest.partner_id == g.user.id)).all()
        from matching import find_matches
        wanted = UserSkill.query.filter_by(user_id=g.user.id, skill_type="learn").all()
        recommended = []
        seen = set()
        for association in wanted:
            for match in find_matches(g.user, association.skill.skill_name):
                if match["id"] not in seen:
                    recommended.append(match)
                    seen.add(match["id"])
        recommended.sort(key=lambda item: item["score"], reverse=True)
        return jsonify(recommended_partners=recommended[:5], upcoming_sessions=[session_json(s) for s in rows if s.status == "Accepted"],
                       pending_count=sum(s.status == "Pending" and s.partner_id == g.user.id for s in rows),
                       completed_count=sum(s.status == "Completed" for s in rows))

    return app


app = create_app()

if __name__ == "__main__":
    with app.app_context():
        db.create_all()
    app.run(port=5000, debug=True)
