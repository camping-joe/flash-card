from pydantic import BaseModel, field_serializer
from datetime import datetime, timezone, timedelta
from typing import List, Optional

CN_TZ = timezone(timedelta(hours=8))

class FlashcardCreate(BaseModel):
    front: str
    back: str
    library_id: int
    difficulty: int = 0

class FlashcardUpdate(BaseModel):
    front: Optional[str] = None
    back: Optional[str] = None
    difficulty: Optional[int] = None

class FlashcardResponse(BaseModel):
    id: int
    front: str
    back: str
    library_id: int
    difficulty: int
    user_id: int
    created_at: datetime

    @field_serializer('created_at')
    def serialize_dt(self, v: datetime) -> str:
        return v.astimezone(CN_TZ).isoformat()

    class Config:
        from_attributes = True

class FlashcardListResponse(BaseModel):
    total: int
    items: List[FlashcardResponse]

class ReviewRequest(BaseModel):
    rating: int  # 1-4

class ReviewResponse(BaseModel):
    message: str
    next_review_at: Optional[datetime]
    interval_days: int

class BatchDeleteRequest(BaseModel):
    ids: List[int]

class BatchUpdateRequest(BaseModel):
    ids: List[int]
    library_id: int

class AllIdsResponse(BaseModel):
    ids: List[int]
