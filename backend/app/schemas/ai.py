from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class AIConfigUpdate(BaseModel):
    provider: Optional[str] = None
    base_url: Optional[str] = None
    api_key: Optional[str] = None
    model: Optional[str] = None
    temperature: Optional[float] = None
    max_tokens: Optional[int] = None

class AIConfigResponse(BaseModel):
    id: int
    user_id: int
    provider: str
    base_url: str
    model: str
    temperature: float
    max_tokens: int

    class Config:
        from_attributes = True

class ExtractionJobResponse(BaseModel):
    id: int
    note_id: Optional[int]
    status: str
    flashcard_count: int
    error_message: Optional[str]
    created_at: datetime
    completed_at: Optional[datetime]

    class Config:
        from_attributes = True
