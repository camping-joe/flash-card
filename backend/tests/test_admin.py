import pytest

async def _register_and_get_token(client, username):
    reg = await client.post("/api/auth/register", json={"username": username, "password": "testpass123"})
    return reg.json()["access_token"]

@pytest.mark.asyncio
async def test_get_ai_config(client):
    token = await _register_and_get_token(client, "aiconfiguser")
    headers = {"Authorization": f"Bearer {token}"}
    resp = await client.get("/api/admin/ai-config", headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["provider"] == "kimi"

@pytest.mark.asyncio
async def test_update_ai_config(client):
    token = await _register_and_get_token(client, "updateaiconfig")
    headers = {"Authorization": f"Bearer {token}"}
    resp = await client.put("/api/admin/ai-config", json={"provider": "openai", "model": "gpt-4", "api_key": "sk-test"}, headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["provider"] == "openai"
    assert data["model"] == "gpt-4"
