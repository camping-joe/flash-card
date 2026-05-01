from pydantic import BaseModel, field_serializer
from datetime import datetime, timezone, timedelta
from typing import List, Optional

CN_TZ = timezone(timedelta(hours=8))

class LibraryCreate(BaseModel):
    name: str
    description: Optional[str] = None
    daily_new_cards: Optional[int] = None
    daily_review_limit: Optional[int] = None

class LibraryUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    daily_new_cards: Optional[int] = None
    daily_review_limit: Optional[int] = None

class LibraryResponse(BaseModel):
    id: int
    name: str
    description: Optional[str]
    user_id: int
    daily_new_cards: Optional[int]
    daily_review_limit: Optional[int]
    created_at: datetime
    updated_at: datetime

    @field_serializer('created_at', 'updated_at')
    def serialize_dt(self, v: datetime) -> str:
        return v.astimezone(CN_TZ).isoformat()

    class Config:
        from_attributes = True

class LibraryListResponse(BaseModel):
    total: int
    items: List[LibraryResponse]
