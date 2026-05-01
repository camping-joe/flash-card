import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy import text
from sqlalchemy.pool import NullPool
from app.main import app
from app.core.config import settings
from app.models.models import Base
from app.core.dependencies import get_db

TEST_DATABASE_URL = settings.DATABASE_URL

# 每个测试前清理的数据库表（按外键依赖顺序）
CLEANUP_TABLES = [
    "study_records",
    "daily_tasks",
    "flashcards",
    "study_plans",
    "algorithm_settings",
    "ai_configs",
    "extraction_jobs",
    "notes",
    "libraries",
    "users",
]


@pytest_asyncio.fixture
async def test_engine():
    """function 级别的 engine，每个测试独立创建和释放，避免连接冲突"""
    engine = create_async_engine(TEST_DATABASE_URL, echo=False, poolclass=NullPool)
    yield engine
    await engine.dispose()


@pytest_asyncio.fixture(autouse=True)
async def cleanup_db(test_engine):
    """每个测试前清理数据库，确保测试互不干扰"""
    async with test_engine.begin() as conn:
        truncate_sql = f"TRUNCATE TABLE {', '.join(CLEANUP_TABLES)} RESTART IDENTITY CASCADE;"
        await conn.execute(text(truncate_sql))
    yield


async def override_get_db():
    engine = create_async_engine(TEST_DATABASE_URL, echo=False)
    SessionLocal = async_sessionmaker(engine, expire_on_commit=False)
    async with SessionLocal() as session:
        yield session


app.dependency_overrides[get_db] = override_get_db


@pytest_asyncio.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest_asyncio.fixture
async def db_session(test_engine):
    SessionLocal = async_sessionmaker(test_engine, expire_on_commit=False)
    async with SessionLocal() as session:
        yield session
