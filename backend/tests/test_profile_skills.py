def test_profile_and_skill_crud(client, register, auth):
    token = register("A", "a@example.edu")["token"]
    headers = auth(token)
    updated = client.put("/api/profile", headers=headers, json={"department": "Math", "year": "2", "availability": ["Friday", "Saturday"]})
    assert updated.status_code == 200
    assert updated.get_json()["user"]["availability"] == ["Friday", "Saturday"]
    assert client.put("/api/profile", headers=headers, json={"availability": "Friday"}).status_code == 400
    added = client.post("/api/profile/skills", headers=headers, json={"skill_name": "Python", "skill_type": "teach"})
    skill = added.get_json()["skill"]
    assert added.status_code == 201
    assert client.post("/api/profile/skills", headers=headers, json={"skill_name": "Python", "skill_type": "teach"}).status_code == 201
    assert client.get("/api/skills", headers=headers).get_json()["skills"][0]["skill_name"] == "Python"
    assert client.delete(f"/api/profile/skills/{skill['id']}?type=teach", headers=headers).status_code == 204
    assert client.delete(f"/api/profile/skills/{skill['id']}?type=teach", headers=headers).status_code == 404
