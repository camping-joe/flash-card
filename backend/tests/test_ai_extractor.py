import pytest
from unittest.mock import patch, AsyncMock, MagicMock
from app.services.ai_extractor import extract_flashcards

@pytest.mark.asyncio
async def test_extract_flashcards_parses_json():
    mock_response = {
        "choices": [{"message": {"content": '[{"front": "Q1", "back": "A1"}]'}}]
    }
    mock_client = AsyncMock()
    # json() 是同步方法，返回 dict，不要用 AsyncMock
    mock_response_obj = MagicMock()
    mock_response_obj.json.return_value = mock_response
    mock_response_obj.status_code = 200
    mock_response_obj.raise_for_status = MagicMock()
    mock_client.post.return_value = mock_response_obj
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)
    with patch("httpx.AsyncClient", return_value=mock_client):
        cards = await extract_flashcards("test note content", "fake-key", "https://api.test.com", "model", 0.3, 2048)
        assert len(cards) == 1
        assert cards[0]["front"] == "Q1"
        assert cards[0]["back"] == "A1"
