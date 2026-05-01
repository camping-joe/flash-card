import pytest

async def _register_and_get_token(client, username):
    reg = await client.post("/api/auth/register", json={"username": username, "password": "testpass123"})
    return reg.json()["access_token"]

@pytest.mark.asyncio
async def test_create_note(client):
    token = await _register_and_get_token(client, "noteuser")
    headers = {"Authorization": f"Bearer {token}"}
    response = await client.post("/api/notes", json={"title": "Test Note", "content": "Hello world"}, headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert data["title"] == "Test Note"
    assert data["content"] == "Hello world"

@pytest.mark.asyncio
async def test_list_notes(client):
    token = await _register_and_get_token(client, "listuser")
    headers = {"Authorization": f"Bearer {token}"}
    await client.post("/api/notes", json={"title": "Note 1", "content": "Content 1"}, headers=headers)
    response = await client.get("/api/notes", headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert data["total"] == 1
    assert len(data["items"]) == 1

@pytest.mark.asyncio
async def test_delete_note(client):
    token = await _register_and_get_token(client, "deluser")
    headers = {"Authorization": f"Bearer {token}"}
    create_resp = await client.post("/api/notes", json={"title": "To Delete", "content": "Content"}, headers=headers)
    note_id = create_resp.json()["id"]
    del_resp = await client.delete(f"/api/notes/{note_id}", headers=headers)
    assert del_resp.status_code == 200
    get_resp = await client.get(f"/api/notes/{note_id}", headers=headers)
    assert get_resp.status_code == 404
