import pytest
from app.core.exceptions import NotFoundException, app_exception_handler

class MockRequest:
    pass

@pytest.mark.asyncio
async def test_app_exception_handler():
    exc = NotFoundException("User not found")
    response = await app_exception_handler(MockRequest(), exc)
    assert response.status_code == 200
    import json
    body = json.loads(response.body)
    assert body["code"] == 404
    assert body["message"] == "User not found"
