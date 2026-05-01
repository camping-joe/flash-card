from pydantic import BaseModel, field_serializer
from datetime import datetime, timezone, timedelta
from typing import List, Optional

CN_TZ = timezone(timedelta(hours=8))

class NoteCreate(BaseModel):
    title: str
    content: str
    source_path: Optional[str] = None

class NoteUpdate(BaseModel):
    title: Optional[str] = None
    content: Optional[str] = None
    source_path: Optional[str] = None

class NoteResponse(BaseModel):
    id: int
    title: str
    content: str
    source_path: Optional[str]
    user_id: int
    created_at: datetime
    updated_at: datetime

    @field_serializer('created_at', 'updated_at')
    def serialize_dt(self, v: datetime) -> str:
        return v.astimezone(CN_TZ).isoformat()

    class Config:
        from_attributes = True

class NoteListResponse(BaseModel):
    total: int
    items: List[NoteResponse]
