import pytest

async def _register_and_get_token(client, username):
    reg = await client.post("/api/auth/register", json={"username": username, "password": "testpass123"})
    return reg.json()["access_token"]

@pytest.mark.asyncio
async def test_create_flashcard(client):
    token = await _register_and_get_token(client, "fcuser")
    headers = {"Authorization": f"Bearer {token}"}
    resp = await client.post("/api/flashcards", json={"front": "Q1", "back": "A1"}, headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["front"] == "Q1"
    assert data["back"] == "A1"

@pytest.mark.asyncio
async def test_review_flashcard(client):
    token = await _register_and_get_token(client, "reviewuser")
    headers = {"Authorization": f"Bearer {token}"}
    card_resp = await client.post("/api/flashcards", json={"front": "Q", "back": "A"}, headers=headers)
    card_id = card_resp.json()["id"]
    review_resp = await client.post(f"/api/flashcards/{card_id}/review", json={"rating": 4}, headers=headers)
    assert review_resp.status_code == 200
    data = review_resp.json()
    assert data["message"] == "Review recorded"
    assert data["interval_days"] == 1

@pytest.mark.asyncio
async def test_list_flashcards(client):
    token = await _register_and_get_token(client, "listfcuser")
    headers = {"Authorization": f"Bearer {token}"}
    await client.post("/api/flashcards", json={"front": "Q1", "back": "A1"}, headers=headers)
    resp = await client.get("/api/flashcards", headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 1
