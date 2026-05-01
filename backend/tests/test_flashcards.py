import pytest

async def _register_and_get_token(client, username):
    reg = await client.post("/api/auth/register", json={"username": username, "password": "testpass123"})
    return reg.json()["access_token"]

async def _create_library(client, token, name="Test Lib"):
    headers = {"Authorization": f"Bearer {token}"}
    resp = await client.post("/api/libraries", json={"name": name, "description": ""}, headers=headers)
    return resp.json()["id"]

@pytest.mark.asyncio
async def test_create_flashcard(client):
    token = await _register_and_get_token(client, "fcuser")
    headers = {"Authorization": f"Bearer {token}"}
    lib_id = await _create_library(client, token)
    resp = await client.post("/api/flashcards", json={"front": "Q1", "back": "A1", "library_id": lib_id}, headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["front"] == "Q1"
    assert data["back"] == "A1"

@pytest.mark.asyncio
async def test_review_flashcard(client):
    token = await _register_and_get_token(client, "reviewuser")
    headers = {"Authorization": f"Bearer {token}"}
    lib_id = await _create_library(client, token)
    card_resp = await client.post("/api/flashcards", json={"front": "Q", "back": "A", "library_id": lib_id}, headers=headers)
    card_id = card_resp.json()["id"]
    review_resp = await client.post(f"/api/flashcards/{card_id}/review", json={"rating": 4}, headers=headers)
    assert review_resp.status_code == 200
    data = review_resp.json()
    assert data["message"] == "Review recorded"
    # 新卡第一次评分 4（简单），interval = new_card_easy_interval（默认 3）
    assert data["interval_days"] == 3

@pytest.mark.asyncio
async def test_list_flashcards(client):
    token = await _register_and_get_token(client, "listfcuser")
    headers = {"Authorization": f"Bearer {token}"}
    lib_id = await _create_library(client, token)
    await client.post("/api/flashcards", json={"front": "Q1", "back": "A1", "library_id": lib_id}, headers=headers)
    resp = await client.get("/api/flashcards", headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 1
