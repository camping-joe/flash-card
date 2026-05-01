from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from typing import Optional
from app.core.dependencies import get_db, get_current_user
from app.models.models import User, Library
from app.schemas.library import LibraryCreate, LibraryUpdate, LibraryResponse, LibraryListResponse

router = APIRouter(prefix="/api/libraries", tags=["libraries"])

@router.get("", response_model=LibraryListResponse)
async def list_libraries(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    base_query = select(Library).where(Library.user_id == current_user.id)
    count_query = select(func.count(Library.id)).where(Library.user_id == current_user.id)
    result = await db.execute(count_query)
    total = result.scalar()
    result = await db.execute(base_query.offset(skip).limit(limit).order_by(Library.updated_at.desc()))
    items = result.scalars().all()
    return {"total": total, "items": items}

@router.post("", response_model=LibraryResponse)
async def create_library(
    data: LibraryCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    library = Library(
        name=data.name,
        description=data.description,
        user_id=current_user.id,
        daily_new_cards=data.daily_new_cards,
        daily_review_limit=data.daily_review_limit,
    )
    db.add(library)
    await db.commit()
    await db.refresh(library)
    return library

@router.put("/{library_id}", response_model=LibraryResponse)
async def update_library(
    library_id: int,
    data: LibraryUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(select(Library).where(Library.id == library_id, Library.user_id == current_user.id))
    library = result.scalar_one_or_none()
    if not library:
        raise HTTPException(status_code=404, detail="Library not found")
    if data.name is not None:
        library.name = data.name
    if data.description is not None:
        library.description = data.description
    if data.daily_new_cards is not None:
        library.daily_new_cards = data.daily_new_cards
    if data.daily_review_limit is not None:
        library.daily_review_limit = data.daily_review_limit
    await db.commit()
    await db.refresh(library)
    return library

@router.delete("/{library_id}")
async def delete_library(
    library_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(select(Library).where(Library.id == library_id, Library.user_id == current_user.id))
    library = result.scalar_one_or_none()
    if not library:
        raise HTTPException(status_code=404, detail="Library not found")
    await db.delete(library)
    await db.commit()
    return {"code": 200, "message": "Deleted", "data": None}
