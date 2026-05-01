import asyncio
from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from sqlalchemy.orm import sessionmaker
from typing import Optional
from app.core.dependencies import get_db, get_current_user
from app.core.security import encrypt_api_key, decrypt_api_key
from app.models.models import User, AIConfig, ExtractionJob, Note, Flashcard, StudyRecord, Library
from app.schemas.ai import AIConfigUpdate, AIConfigResponse
from app.schemas.study import AlgorithmSettingsResponse, AlgorithmSettingsUpdate
from app.services.ai_extractor import extract_flashcards, split_by_sections
from app.models.models import AlgorithmSettings

router = APIRouter(prefix="/api/admin", tags=["admin"])

@router.get("/ai-config", response_model=AIConfigResponse)
async def get_ai_config(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(select(AIConfig).where(AIConfig.user_id == current_user.id))
    config = result.scalar_one_or_none()
    if not config:
        config = AIConfig(user_id=current_user.id)
        db.add(config)
        await db.commit()
        await db.refresh(config)
    return config

@router.put("/ai-config", response_model=AIConfigResponse)
async def update_ai_config(
    data: AIConfigUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(select(AIConfig).where(AIConfig.user_id == current_user.id))
    config = result.scalar_one_or_none()
    if not config:
        config = AIConfig(user_id=current_user.id)
        db.add(config)
    if data.provider is not None:
        config.provider = data.provider
    if data.base_url is not None:
        config.base_url = data.base_url
    if data.api_key is not None:
        config.api_key_encrypted = encrypt_api_key(data.api_key)
    if data.model is not None:
        config.model = data.model
    if data.temperature is not None:
        config.temperature = data.temperature
    if data.max_tokens is not None:
        config.max_tokens = data.max_tokens
    await db.commit()
    await db.refresh(config)
    return config

@router.get("/algorithm-settings", response_model=AlgorithmSettingsResponse)
async def get_algorithm_settings(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(select(AlgorithmSettings).where(AlgorithmSettings.user_id == current_user.id))
    settings = result.scalar_one_or_none()
    if not settings:
        settings = AlgorithmSettings(user_id=current_user.id)
        db.add(settings)
        await db.commit()
        await db.refresh(settings)
    return settings

@router.put("/algorithm-settings", response_model=AlgorithmSettingsResponse)
async def update_algorithm_settings(
    data: AlgorithmSettingsUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(select(AlgorithmSettings).where(AlgorithmSettings.user_id == current_user.id))
    settings = result.scalar_one_or_none()
    if not settings:
        settings = AlgorithmSettings(user_id=current_user.id)
        db.add(settings)
    if data.new_card_easy_interval is not None:
        settings.new_card_easy_interval = data.new_card_easy_interval
    if data.new_card_hard_interval is not None:
        settings.new_card_hard_interval = data.new_card_hard_interval
    if data.second_repetition_interval is not None:
        settings.second_repetition_interval = data.second_repetition_interval
    if data.min_ease_factor is not None:
        settings.min_ease_factor = data.min_ease_factor
    if data.initial_ease_factor is not None:
        settings.initial_ease_factor = data.initial_ease_factor
    await db.commit()
    await db.refresh(settings)
    return settings

@router.get("/extraction-jobs")
async def list_extraction_jobs(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    base_query = select(ExtractionJob).where(ExtractionJob.user_id == current_user.id)
    count_query = select(func.count(ExtractionJob.id)).where(ExtractionJob.user_id == current_user.id)
    result = await db.execute(count_query)
    total = result.scalar()
    result = await db.execute(base_query.offset(skip).limit(limit).order_by(ExtractionJob.created_at.desc()))
    items = result.scalars().all()
    return {
        "total": total,
        "items": [
            {
                "id": j.id,
                "note_id": j.note_id,
                "status": j.status,
                "flashcard_count": j.flashcard_count,
                "error_message": j.error_message,
                "progress_message": j.progress_message,
                "created_at": to_cn_time(j.created_at),
                "completed_at": to_cn_time(j.completed_at),
            }
            for j in items
        ]
    }

from datetime import timezone, timedelta

CN_TZ = timezone(timedelta(hours=8))

def to_cn_time(dt):
    if dt:
        return dt.astimezone(CN_TZ).isoformat()
    return None

async def _run_extraction(job_id: int):
    from app.core.config import engine
    AsyncSessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    async with AsyncSessionLocal() as session:
        job_result = await session.execute(select(ExtractionJob).where(ExtractionJob.id == job_id))
        job = job_result.scalar_one_or_none()
        if not job:
            return

        note_id = job.note_id
        user_id = job.user_id

        note_result = await session.execute(select(Note).where(Note.id == note_id))
        note = note_result.scalar_one_or_none()
        if not note:
            job.status = "failed"
            job.error_message = "Note not found"
            await session.commit()
            return

        config_result = await session.execute(select(AIConfig).where(AIConfig.user_id == user_id))
        config = config_result.scalar_one_or_none()
        if not config or not config.api_key_encrypted:
            job.status = "failed"
            job.error_message = "AI config not found"
            await session.commit()
            return

        try:
            job.status = "running"
            job.progress_message = "正在准备提取..."
            await session.commit()

            # Ensure note has an associated library
            library_id = note.library_id
            if not library_id:
                lib_result = await session.execute(select(Library).where(Library.name == note.title, Library.user_id == user_id))
                library = lib_result.scalar_one_or_none()
                if not library:
                    library = Library(name=note.title, user_id=user_id)
                    session.add(library)
                    await session.flush()
                library_id = library.id
                note.library_id = library_id
                await session.flush()

            api_key = decrypt_api_key(config.api_key_encrypted)

            async def on_progress(current: int, total: int, title: str):
                if total > 1:
                    job.progress_message = f"正在提取：{title} ({current}/{total})"
                else:
                    job.progress_message = f"正在提取：{title}"
                await session.commit()

            # 超时保护：每章至少给 90 秒，最少 5 分钟，避免多章节笔记总时间不够
            sections = split_by_sections(note.content)
            timeout = max(300, len(sections) * 90)
            cards = await asyncio.wait_for(
                extract_flashcards(
                    note.content, api_key, config.base_url, config.model,
                    config.temperature, config.max_tokens, on_progress=on_progress
                ),
                timeout=timeout,
            )

            # 防御性检查：确保 cards 是列表
            if not isinstance(cards, list):
                job.status = "failed"
                job.error_message = f"AI returned unexpected type: {type(cards).__name__}, expected list"
                job.progress_message = None
                await session.commit()
                return

            if not cards:
                job.status = "failed"
                job.error_message = "AI returned no valid flashcards"
                job.progress_message = None
                await session.commit()
                return

            # 检查任务是否已被取消
            await session.refresh(job)
            if job.status == "cancelled":
                return

            job.progress_message = f"已生成 {len(cards)} 张卡片，正在保存..."
            await session.commit()

            created_count = 0
            for idx, card_data in enumerate(cards):
                if not isinstance(card_data, dict):
                    continue
                front = card_data.get("front")
                back = card_data.get("back")
                if not front or not back:
                    continue
                try:
                    flashcard = Flashcard(front=str(front).strip(), back=str(back).strip(), library_id=library_id, user_id=user_id)
                    session.add(flashcard)
                    await session.flush()
                    record = StudyRecord(user_id=user_id, flashcard_id=flashcard.id)
                    session.add(record)
                    created_count += 1
                except Exception:
                    pass

            job.status = "completed"
            job.flashcard_count = created_count
            job.completed_at = func.now()
            job.progress_message = None
            await session.commit()
        except asyncio.TimeoutError:
            job.status = "failed"
            job.error_message = "提取超时：AI 响应时间超过 5 分钟，请检查网络或稍后重试"
            job.progress_message = None
            await session.commit()
        except Exception as e:
            import traceback
            job.status = "failed"
            job.error_message = traceback.format_exc()[:2000]
            job.progress_message = None
            await session.commit()

@router.post("/notes/{note_id}/extract")
async def trigger_extraction(
    note_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(select(Note).where(Note.id == note_id, Note.user_id == current_user.id))
    note = result.scalar_one_or_none()
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")

    job = ExtractionJob(note_id=note_id, user_id=current_user.id, status="pending")
    db.add(job)
    await db.commit()
    await db.refresh(job)

    asyncio.create_task(_run_extraction(job.id))
    return {"code": 200, "message": "Extraction started", "data": {"job_id": job.id}}

@router.post("/extraction-jobs/{job_id}/cancel")
async def cancel_extraction_job(
    job_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(select(ExtractionJob).where(ExtractionJob.id == job_id, ExtractionJob.user_id == current_user.id))
    job = result.scalar_one_or_none()
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    if job.status not in ("pending", "running"):
        raise HTTPException(status_code=400, detail="Job cannot be cancelled")
    job.status = "cancelled"
    job.progress_message = None
    job.error_message = "用户已取消"
    job.completed_at = func.now()
    await db.commit()
    return {"code": 200, "message": "Job cancelled"}
