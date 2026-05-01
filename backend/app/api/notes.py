from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from typing import Optional
from app.core.dependencies import get_db, get_current_user
from app.models.models import User, Note, Flashcard, Library
from app.schemas.note import NoteCreate, NoteUpdate, NoteResponse, NoteListResponse

router = APIRouter(prefix="/api/notes", tags=["notes"])

@router.get("", response_model=NoteListResponse)
async def list_notes(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    q: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    base_query = select(Note).where(Note.user_id == current_user.id)
    count_query = select(func.count(Note.id)).where(Note.user_id == current_user.id)
    if q:
        base_query = base_query.where(Note.title.contains(q))
        count_query = count_query.where(Note.title.contains(q))
    result = await db.execute(count_query)
    total = result.scalar()
    result = await db.execute(base_query.offset(skip).limit(limit).order_by(Note.updated_at.desc()))
    items = result.scalars().all()
    return {"total": total, "items": items}

@router.post("", response_model=NoteResponse)
async def create_note(
    data: NoteCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    note = Note(title=data.title, content=data.content, source_path=data.source_path, user_id=current_user.id)
    db.add(note)
    await db.commit()
    await db.refresh(note)
    return note

@router.get("/{note_id}", response_model=NoteResponse)
async def get_note(
    note_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(select(Note).where(Note.id == note_id, Note.user_id == current_user.id))
    note = result.scalar_one_or_none()
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    return note

@router.put("/{note_id}", response_model=NoteResponse)
async def update_note(
    note_id: int,
    data: NoteUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(select(Note).where(Note.id == note_id, Note.user_id == current_user.id))
    note = result.scalar_one_or_none()
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    if data.title is not None:
        note.title = data.title
    if data.content is not None:
        note.content = data.content
    if data.source_path is not None:
        note.source_path = data.source_path
    await db.commit()
    await db.refresh(note)
    return note

@router.post("/push", response_model=NoteResponse)
async def push_note(
    data: NoteCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(select(Note).where(Note.title == data.title, Note.user_id == current_user.id))
    note = result.scalar_one_or_none()
    if note:
        note.content = data.content
        if data.source_path:
            note.source_path = data.source_path
        await db.commit()
        await db.refresh(note)
    else:
        note = Note(title=data.title, content=data.content, source_path=data.source_path, user_id=current_user.id)
        db.add(note)
        await db.commit()
        await db.refresh(note)

    # Auto-create or reuse library with the same name as the note
    lib_result = await db.execute(select(Library).where(Library.name == note.title, Library.user_id == current_user.id))
    library = lib_result.scalar_one_or_none()
    if not library:
        library = Library(name=note.title, user_id=current_user.id)
        db.add(library)
        await db.commit()
        await db.refresh(library)
    note.library_id = library.id
    await db.commit()
    await db.refresh(note)
    return note

@router.delete("/{note_id}")
async def delete_note(
    note_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    result = await db.execute(select(Note).where(Note.id == note_id, Note.user_id == current_user.id))
    note = result.scalar_one_or_none()
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    await db.delete(note)
    await db.commit()
    return {"code": 200, "message": "Deleted", "data": None}

@router.get("/{note_id}/flashcards")
async def get_note_flashcards(
    note_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    note_result = await db.execute(select(Note).where(Note.id == note_id, Note.user_id == current_user.id))
    note = note_result.scalar_one_or_none()
    if not note or not note.library_id:
        return {"code": 200, "message": "success", "data": []}
    result = await db.execute(
        select(Flashcard).where(Flashcard.library_id == note.library_id, Flashcard.user_id == current_user.id)
    )
    items = result.scalars().all()
    return {"code": 200, "message": "success", "data": items}
