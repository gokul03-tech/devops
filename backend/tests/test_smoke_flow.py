"""In-process end-to-end equivalent of scripts/smoke_test.sh for environments without Bash."""


def test_register_match_session_review_smoke(client, register, auth):
    learner = register("Smoke Learner", "smoke-learner@example.edu")
    tutor = register("Smoke Tutor", "smoke-tutor@example.edu")
    learner_headers = auth(learner["token"])
    tutor_headers = auth(tutor["token"])

    skill = client.post("/api/profile/skills", headers=tutor_headers,
                        json={"skill_name": "Integration Test Skill", "skill_type": "teach"})
    assert skill.status_code == 201
    assert client.post("/api/profile/skills", headers=learner_headers,
                       json={"skill_name": "Linux", "skill_type": "teach"}).status_code == 201

    matches = client.get("/api/matches?skill=Integration%20Test%20Skill", headers=learner_headers).get_json()["matches"]
    assert [candidate["id"] for candidate in matches] == [tutor["user"]["id"]]
    assert matches[0]["match_type"] == "Mutual Exchange"

    session = client.post("/api/sessions", headers=learner_headers,
                          json={"partner_id": tutor["user"]["id"], "skill_id": skill.get_json()["skill"]["id"],
                                "proposed_time": "Tomorrow at 4pm"})
    session_id = session.get_json()["session"]["id"]
    assert session.status_code == 201
    assert client.patch(f"/api/sessions/{session_id}", headers=tutor_headers,
                        json={"action": "accept"}).get_json()["session"]["status"] == "Accepted"
    assert client.patch(f"/api/sessions/{session_id}", headers=tutor_headers,
                        json={"action": "complete"}).get_json()["session"]["status"] == "Completed"
    assert client.post(f"/api/sessions/{session_id}/review", headers=learner_headers,
                       json={"rating": 5, "feedback": "Clear and useful session."}).status_code == 201
    history = client.get("/api/history", headers=learner_headers).get_json()["history"]
    assert history[0]["session"]["id"] == session_id
    assert history[0]["reviews"][0]["rating"] == 5
    assert client.get("/api/health").get_json() == {"status": "ok"}
