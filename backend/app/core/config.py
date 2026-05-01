from pydantic_settings import BaseSettings
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession

class Settings(BaseSettings):
    DATABASE_URL: str = "postgresql+asyncpg://localhost/flash-card-data"
    SECRET_KEY: str = "change-me-in-production"
    ENCRYPTION_KEY: str = "change-me-32-bytes-long-key!!"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 10080  # 7 days
    ALGORITHM: str = "HS256"

    class Config:
        env_file = ".env"
        extra = "ignore"

settings = Settings()

engine = create_async_engine(settings.DATABASE_URL, echo=False, connect_args={"ssl": False})
AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False)
