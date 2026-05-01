import pytest

async def _register_and_get_token(client, username):
    reg = await client.post("/api/auth/register", json={"username": username, "password": "testpass123"})
    return reg.json()["access_token"]

@pytest.mark.asyncio
async def test_get_plan(client):
    token = await _register_and_get_token(client, "planuser")
    headers = {"Authorization": f"Bearer {token}"}
    resp = await client.get("/api/study/plan", headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["daily_new_cards"] == 20

@pytest.mark.asyncio
async def test_update_plan(client):
    token = await _register_and_get_token(client, "updateplanuser")
    headers = {"Authorization": f"Bearer {token}"}
    resp = await client.put("/api/study/plan", json={"name": "My Plan", "daily_new_cards": 10, "daily_review_limit": 50}, headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["daily_new_cards"] == 10

@pytest.mark.asyncio
async def test_get_stats(client):
    token = await _register_and_get_token(client, "statsuser")
    headers = {"Authorization": f"Bearer {token}"}
    resp = await client.get("/api/study/stats", headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["total_flashcards"] == 0
