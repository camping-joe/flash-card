import os
from app.core.config import Settings

def test_settings_loads_database_url():
    os.environ["DATABASE_URL"] = "postgresql+asyncpg://user:pass@localhost/db"
    os.environ["SECRET_KEY"] = "test-secret"
    os.environ["ENCRYPTION_KEY"] = "test-encryption-key-32bytes!!"
    settings = Settings()
    assert settings.DATABASE_URL == "postgresql+asyncpg://user:pass@localhost/db"
    assert settings.SECRET_KEY == "test-secret"
