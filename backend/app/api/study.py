from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload
from typing import List
from datetime import datetime, timezone, date
from app.core.dependencies import get_db, get_current_user
from app.models.models import User, StudyRecord, Flashcard, StudyPlan, DailyTask, AlgorithmSettings
from app.schemas.study import StudyPlanCreate, StudyPlanResponse, TodayResponse, StatsResponse, TodayCard, AlgorithmSettingsData, StudyRecordItem

router = APIRouter(prefix="/api/study", tags=["study"])

@router.get("/today", response_model=TodayResponse)
async def get_today(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # 默认学习目标（当卡库未单独设置时）
    DEFAULT_DAILY_NEW = 20
    DEFAULT_DAILY_REVIEW = 100

    now = datetime.now(timezone.utc)

    # 获取用户所有卡库
    lib_result = await db.execute(select(Library).where(Library.user_id == current_user.id))
    libraries = lib_result.scalars().all()

    cards = []
    total_review_count = 0
    total_new_count = 0

    if not libraries:
        # 无卡库时不返回任何卡片
        pass
    else:
        for lib in libraries:
            lib_new_limit = lib.daily_new_cards if lib.daily_new_cards is not None else DEFAULT_DAILY_NEW
            lib_review_limit = lib.daily_review_limit if lib.daily_review_limit is not None else DEFAULT_DAILY_REVIEW

            # 该卡库下到期的新卡和复习卡
            review_query = (
                select(StudyRecord)
                .join(Flashcard, StudyRecord.flashcard_id == Flashcard.id)
                .options(selectinload(StudyRecord.flashcard))
                .where(
                    StudyRecord.user_id == current_user.id,
                    StudyRecord.next_review_at.is_not(None),
                    StudyRecord.next_review_at <= now,
                    Flashcard.library_id == lib.id,
                )
            )
            result = await db.execute(review_query)
            review_records = result.scalars().all()

            new_query = (
                select(StudyRecord)
                .join(Flashcard, StudyRecord.flashcard_id == Flashcard.id)
                .options(selectinload(StudyRecord.flashcard))
                .where(
                    StudyRecord.user_id == current_user.id,
                    StudyRecord.repetitions == 0,
                    StudyRecord.next_review_at.is_(None),
                    Flashcard.library_id == lib.id,
                )
            )
            result = await db.execute(new_query)
            new_records = result.scalars().all()

            for r in review_records[:lib_review_limit]:
                cards.append(TodayCard(
                    flashcard_id=r.flashcard_id,
                    front=r.flashcard.front,
                    back=r.flashcard.back,
                    is_new=r.repetitions == 0,
                    repetitions=r.repetitions,
                    ease_factor=r.ease_factor,
                    interval_days=r.interval_days,
                ))
                total_review_count += 1
            for r in new_records[:lib_new_limit]:
                cards.append(TodayCard(
                    flashcard_id=r.flashcard_id,
                    front=r.flashcard.front,
                    back=r.flashcard.back,
                    is_new=True,
                    repetitions=r.repetitions,
                    ease_factor=r.ease_factor,
                    interval_days=r.interval_days,
                ))
                total_new_count += 1

    algo_result = await db.execute(select(AlgorithmSettings).where(AlgorithmSettings.user_id == current_user.id))
    algo = algo_result.scalar_one_or_none()
    algorithm_settings = AlgorithmSettingsData(
        new_card_easy_interval=algo.new_card_easy_interval if algo else 3,
        new_card_hard_interval=algo.new_card_hard_interval if algo else 1,
        second_repetition_interval=algo.second_repetition_interval if algo else 6,
        min_ease_factor=algo.min_ease_factor if algo else 1.3,
    )

    return TodayResponse(
        review_count=total_review_count,
        new_count=total_new_count,
        cards=cards,
        algorithm_settings=algorithm_settings,
    )

@router.get("/plan", response_model=StudyPlanResponse)
async def get_plan(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(select(StudyPlan).where(StudyPlan.user_id == current_user.id))
    plan = result.scalar_one_or_none()
    if not plan:
        plan = StudyPlan(user_id=current_user.id)
        db.add(plan)
        await db.commit()
        await db.refresh(plan)
    return plan

@router.put("/plan", response_model=StudyPlanResponse)
async def update_plan(
    data: StudyPlanCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(select(StudyPlan).where(StudyPlan.user_id == current_user.id))
    plan = result.scalar_one_or_none()
    if not plan:
        plan = StudyPlan(user_id=current_user.id)
        db.add(plan)
    plan.name = data.name
    plan.daily_new_cards = data.daily_new_cards
    plan.daily_review_limit = data.daily_review_limit
    await db.commit()
    await db.refresh(plan)
    return plan

@router.get("/records", response_model=List[StudyRecordItem])
async def get_study_records(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(
        select(StudyRecord).where(StudyRecord.user_id == current_user.id)
    )
    records = result.scalars().all()
    return records

@router.get("/daily-task")
async def get_daily_task(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    today = date.today()
    result = await db.execute(
        select(DailyTask).where(DailyTask.user_id == current_user.id, DailyTask.date == today)
    )
    task = result.scalar_one_or_none()
    if task:
        return {
            "date": task.date.isoformat(),
            "new_cards_done": task.new_cards_done,
            "review_done": task.review_done,
            "daily_new_cards": task.new_cards_target,
            "daily_review_limit": task.review_target,
        }
    return {
        "date": None,
        "new_cards_done": 0,
        "review_done": 0,
        "daily_new_cards": 20,
        "daily_review_limit": 100,
    }

@router.get("/stats", response_model=StatsResponse)
async def get_stats(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    total_result = await db.execute(select(func.count(Flashcard.id)).where(Flashcard.user_id == current_user.id))
    total_flashcards = total_result.scalar()

    mastered_result = await db.execute(
        select(func.count(StudyRecord.id)).where(
            StudyRecord.user_id == current_user.id,
            StudyRecord.interval_days >= 21
        )
    )
    mastered = mastered_result.scalar()

    today = date.today()
    today_result = await db.execute(
        select(DailyTask).where(
            DailyTask.user_id == current_user.id,
            DailyTask.date == today
        )
    )
    reviews_today = 0
    new_cards_today = 0
    task = today_result.scalar_one_or_none()
    if task:
        reviews_today = task.review_done
        new_cards_today = task.new_cards_done

    return StatsResponse(
        total_flashcards=total_flashcards or 0,
        mastered_flashcards=mastered or 0,
        reviews_today=reviews_today,
        new_cards_today=new_cards_today,
        streak_days=0,
        weekly_reviews=[0, 0, 0, 0, 0, 0, 0]
    )

@router.post("/reset-progress")
async def reset_progress(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    await db.execute(
        DailyTask.__table__.delete().where(DailyTask.user_id == current_user.id)
    )
    await db.execute(
        StudyRecord.__table__.delete().where(StudyRecord.user_id == current_user.id)
    )
    await db.commit()
    return {"message": "学习进度已重置"}
