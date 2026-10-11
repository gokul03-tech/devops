def setup_pair(client, register, auth, suffix=""):
    requester = register("Requester" + suffix, f"r{suffix}@example.edu")
    partner = register("Partner" + suffix, f"p{suffix}@example.edu")
    rheaders, pheaders = auth(requester["token"]), auth(partner["token"])
    skill = client.post("/api/profile/skills", headers=pheaders, json={"skill_name": "Python", "skill_type": "teach"}).get_json()["skill"]
    session = client.post("/api/sessions", headers=rheaders, json={"partner_id": partner["user"]["id"], "skill_id": skill["id"], "proposed_time": "Friday 4pm"})
    return requester, partner, rheaders, pheaders, session.get_json()["session"]


def test_session_lifecycle_and_permissions(client, register, auth):
    _, _, rheaders, pheaders, session = setup_pair(client, register, auth)
    sid = session["id"]
    outsider = auth(register("Outsider", "o@example.edu")["token"])
    assert client.get("/api/sessions", headers=rheaders).get_json()["sessions"]
    assert client.patch(f"/api/sessions/{sid}", headers=outsider, json={"action": "cancel"}).status_code == 403
    assert client.patch(f"/api/sessions/{sid}", headers=rheaders, json={"action": "accept"}).status_code == 403
    assert client.patch(f"/api/sessions/{sid}", headers=pheaders, json={"action": "accept"}).get_json()["session"]["status"] == "Accepted"
    assert client.patch(f"/api/sessions/{sid}", headers=rheaders, json={"action": "complete"}).get_json()["session"]["status"] == "Completed"
    assert client.patch(f"/api/sessions/{sid}", headers=rheaders, json={"action": "complete"}).status_code == 409
    assert client.get("/api/dashboard", headers=pheaders).get_json()["completed_count"] == 1


def test_reviews_require_completed_participation_and_are_unique(client, register, auth):
    _, _, rheaders, pheaders, session = setup_pair(client, register, auth)
    sid = session["id"]
    assert client.post(f"/api/sessions/{sid}/review", headers=rheaders, json={"rating": 5}).status_code == 403
    client.patch(f"/api/sessions/{sid}", headers=pheaders, json={"action": "accept"})
    client.patch(f"/api/sessions/{sid}", headers=pheaders, json={"action": "complete"})
    assert client.post(f"/api/sessions/{sid}/review", headers=rheaders, json={"rating": 6}).status_code == 400
    assert client.post(f"/api/sessions/{sid}/review", headers=rheaders, json={"rating": 5, "feedback": "Great"}).status_code == 201
    assert client.post(f"/api/sessions/{sid}/review", headers=rheaders, json={"rating": 4}).status_code == 409
    assert client.post(f"/api/sessions/{sid}/review", headers=pheaders, json={"rating": 4}).status_code == 201
    assert len(client.get("/api/history", headers=rheaders).get_json()["history"][0]["reviews"]) == 2


def test_reject_and_cancel_transitions(client, register, auth):
    _, partner, rheaders, pheaders, session = setup_pair(client, register, auth)
    sid = session["id"]
    assert client.patch(f"/api/sessions/{sid}", headers=pheaders, json={"action": "reject"}).get_json()["session"]["status"] == "Rejected"
    _, _, r2, p2, session2 = setup_pair(client, register, auth, "2")
    assert client.patch(f"/api/sessions/{session2['id']}", headers=r2, json={"action": "cancel"}).get_json()["session"]["status"] == "Cancelled"
