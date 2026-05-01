import pytest
from unittest.mock import patch, AsyncMock
from app.services.ai_extractor import extract_flashcards

@pytest.mark.asyncio
async def test_extract_flashcards_parses_json():
    mock_response = {
        "choices": [{"message": {"content": '[{"front": "Q1", "back": "A1"}]'}}]
    }
    mock_client = AsyncMock()
    mock_client.post.return_value = AsyncMock(json=AsyncMock(return_value=mock_response), status_code=200)
    with patch("httpx.AsyncClient", return_value=mock_client):
        # The patch needs to be an async context manager
        mock_client.__aenter__ = AsyncMock(return_value=mock_client)
        mock_client.__aexit__ = AsyncMock(return_value=False)
        cards = await extract_flashcards("test note content", "fake-key", "https://api.test.com", "model", 0.3, 2048)
        assert len(cards) == 1
        assert cards[0]["front"] == "Q1"
        assert cards[0]["back"] == "A1"
