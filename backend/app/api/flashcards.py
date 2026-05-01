from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from typing import Optional
from datetime import date
from app.core.dependencies import get_db, get_current_user
from app.models.models import User, Flashcard, StudyRecord, DailyTask, AlgorithmSettings
from app.schemas.flashcard import FlashcardCreate, FlashcardResponse, FlashcardListResponse, ReviewRequest, ReviewResponse, BatchDeleteRequest, BatchUpdateRequest, AllIdsResponse
from fastapi import HTTPException
from app.services.sm2 import calculate_sm2

router = APIRouter(prefix="/api/flashcards", tags=["flashcards"])

@router.get("", response_model=FlashcardListResponse)
async def list_flashcards(
    library_id: Optional[int] = None,
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    base_query = select(Flashcard).where(Flashcard.user_id == current_user.id)
    count_query = select(func.count(Flashcard.id)).where(Flashcard.user_id == current_user.id)
    if library_id:
        base_query = base_query.where(Flashcard.library_id == library_id)
        count_query = count_query.where(Flashcard.library_id == library_id)
    result = await db.execute(count_query)
    total = result.scalar()
    result = await db.execute(base_query.offset(skip).limit(limit).order_by(Flashcard.created_at.desc()))
    items = result.scalars().all()
    return {"total": total, "items": items}

@router.post("", response_model=FlashcardResponse)
async def create_flashcard(
    data: FlashcardCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    card = Flashcard(front=data.front, back=data.back, library_id=data.library_id, difficulty=data.difficulty, user_id=current_user.id)
    db.add(card)
    await db.commit()
    await db.refresh(card)
    algo_result = await db.execute(select(AlgorithmSettings).where(AlgorithmSettings.user_id == current_user.id))
    algo = algo_result.scalar_one_or_none()
    initial_ef = algo.initial_ease_factor if algo else 2.5
    record = StudyRecord(user_id=current_user.id, flashcard_id=card.id, ease_factor=initial_ef)
    db.add(record)
    await db.commit()
    return card

@router.put("/{card_id}", response_model=FlashcardResponse)
async def update_flashcard(
    card_id: int,
    data: FlashcardCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(select(Flashcard).where(Flashcard.id == card_id, Flashcard.user_id == current_user.id))
    card = result.scalar_one_or_none()
    if not card:
        raise HTTPException(status_code=404, detail="Flashcard not found")
    card.front = data.front
    card.back = data.back
    card.library_id = data.library_id
    card.difficulty = data.difficulty
    await db.commit()
    await db.refresh(card)
    return card

@router.delete("/{card_id}")
async def delete_flashcard(
    card_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(select(Flashcard).where(Flashcard.id == card_id, Flashcard.user_id == current_user.id))
    card = result.scalar_one_or_none()
    if not card:
        raise HTTPException(status_code=404, detail="Flashcard not found")
    await db.delete(card)
    await db.commit()
    return {"code": 200, "message": "Deleted", "data": None}

@router.get("/all-ids", response_model=AllIdsResponse)
async def list_all_flashcard_ids(
    library_id: Optional[int] = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    query = select(Flashcard.id).where(Flashcard.user_id == current_user.id)
    if library_id:
        query = query.where(Flashcard.library_id == library_id)
    result = await db.execute(query)
    ids = [row[0] for row in result.all()]
    return {"ids": ids}

@router.delete("/batch")
async def batch_delete_flashcards(
    data: BatchDeleteRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not data.ids:
        raise HTTPException(status_code=400, detail="No IDs provided")
    result = await db.execute(
        select(Flashcard).where(Flashcard.id.in_(data.ids), Flashcard.user_id == current_user.id)
    )
    cards = result.scalars().all()
    for card in cards:
        await db.delete(card)
    await db.commit()
    return {"code": 200, "message": f"Deleted {len(cards)} flashcards", "data": None}

@router.put("/batch/library")
async def batch_update_flashcard_library(
    data: BatchUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if not data.ids:
        raise HTTPException(status_code=400, detail="No IDs provided")
    result = await db.execute(
        select(Flashcard).where(Flashcard.id.in_(data.ids), Flashcard.user_id == current_user.id)
    )
    cards = result.scalars().all()
    for card in cards:
        card.library_id = data.library_id
    await db.commit()
    return {"code": 200, "message": f"Updated {len(cards)} flashcards", "data": None}

@router.post("/{card_id}/review", response_model=ReviewResponse)
async def review_flashcard(
    card_id: int,
    data: ReviewRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(
        select(StudyRecord).where(StudyRecord.flashcard_id == card_id, StudyRecord.user_id == current_user.id)
    )
    record = result.scalar_one_or_none()

    algo_result = await db.execute(
        select(AlgorithmSettings).where(AlgorithmSettings.user_id == current_user.id)
    )
    algo = algo_result.scalar_one_or_none()

    if not record:
        initial_ef = algo.initial_ease_factor if algo else 2.5
        record = StudyRecord(
            user_id=current_user.id,
            flashcard_id=card_id,
            ease_factor=initial_ef,
        )
        db.add(record)
        await db.commit()
        await db.refresh(record)

    # 在更新记录前判断是否是新卡
    is_new_card = record.repetitions == 0

    result = calculate_sm2(
        record.repetitions,
        record.ease_factor,
        record.interval_days,
        data.rating,
        new_card_easy_interval=algo.new_card_easy_interval if algo else 3,
        new_card_hard_interval=algo.new_card_hard_interval if algo else 1,
        second_repetition_interval=algo.second_repetition_interval if algo else 6,
        min_ease_factor=algo.min_ease_factor if algo else 1.3,
    )
    record.repetitions = result["repetitions"]
    record.ease_factor = result["ease_factor"]
    record.interval_days = result["interval"]
    record.next_review_at = result["next_review_at"]
    record.last_review_at = func.now()
    await db.commit()

    # 更新今日任务统计（rating=1 重来不计入任何统计）
    today = date.today()
    daily_task_result = await db.execute(
        select(DailyTask).where(DailyTask.user_id == current_user.id, DailyTask.date == today)
    )
    daily_task = daily_task_result.scalar_one_or_none()
    if data.rating != 1:
        if daily_task:
            if is_new_card:
                daily_task.new_cards_done += 1
            else:
                daily_task.review_done += 1
        else:
            daily_task = DailyTask(
                user_id=current_user.id,
                date=today,
                new_cards_done=1 if is_new_card else 0,
                review_done=0 if is_new_card else 1,
            )
            db.add(daily_task)
        await db.commit()

    return ReviewResponse(
        message="Review recorded",
        next_review_at=result["next_review_at"],
        interval_days=result["interval"]
    )
