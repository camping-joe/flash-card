from pydantic import BaseModel
from datetime import datetime
from typing import List, Optional

class StudyPlanCreate(BaseModel):
    name: str = "default plan"
    daily_new_cards: int = 20
    daily_review_limit: int = 100

class StudyPlanResponse(BaseModel):
    id: int
    user_id: int
    name: str
    daily_new_cards: int
    daily_review_limit: int

    class Config:
        from_attributes = True

class TodayCard(BaseModel):
    flashcard_id: int
    front: str
    back: str
    is_new: bool
    repetitions: int
    ease_factor: float
    interval_days: int

class AlgorithmSettingsData(BaseModel):
    new_card_easy_interval: int
    new_card_hard_interval: int
    second_repetition_interval: int
    min_ease_factor: float

class TodayResponse(BaseModel):
    review_count: int
    new_count: int
    cards: List[TodayCard]
    algorithm_settings: AlgorithmSettingsData

class StatsResponse(BaseModel):
    total_flashcards: int
    mastered_flashcards: int
    reviews_today: int
    new_cards_today: int
    streak_days: int
    weekly_reviews: List[int]

class StudyRecordItem(BaseModel):
    flashcard_id: int
    interval_days: int
    ease_factor: float
    repetitions: int
    next_review_at: Optional[datetime]
    last_review_at: Optional[datetime]

    class Config:
        from_attributes = True

class AlgorithmSettingsResponse(BaseModel):
    id: int
    user_id: int
    new_card_easy_interval: int
    new_card_hard_interval: int
    second_repetition_interval: int
    min_ease_factor: float
    initial_ease_factor: float

    class Config:
        from_attributes = True

class AlgorithmSettingsUpdate(BaseModel):
    new_card_easy_interval: int = 3
    new_card_hard_interval: int = 1
    second_repetition_interval: int = 6
    min_ease_factor: float = 1.3
    initial_ease_factor: float = 2.5
