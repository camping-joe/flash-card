import pytest
from app.core.dependencies import get_db

@pytest.mark.asyncio
async def test_get_db_yields_session():
    async for session in get_db():
        from sqlalchemy.ext.asyncio import AsyncSession
        assert isinstance(session, AsyncSession)
        break
