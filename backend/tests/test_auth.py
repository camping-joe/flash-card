import pytest

@pytest.mark.asyncio
async def test_register_success(client):
    response = await client.post("/api/auth/register", json={"username": "testuser", "password": "testpass123"})
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"

@pytest.mark.asyncio
async def test_register_duplicate(client):
    await client.post("/api/auth/register", json={"username": "dupuser", "password": "testpass123"})
    response = await client.post("/api/auth/register", json={"username": "dupuser", "password": "testpass123"})
    assert response.status_code == 400

@pytest.mark.asyncio
async def test_login_success(client):
    await client.post("/api/auth/register", json={"username": "loginuser", "password": "testpass123"})
    response = await client.post("/api/auth/login", json={"username": "loginuser", "password": "testpass123"})
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data

@pytest.mark.asyncio
async def test_login_invalid(client):
    response = await client.post("/api/auth/login", json={"username": "nouser", "password": "wrongpass"})
    assert response.status_code == 401
