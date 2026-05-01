from sqlalchemy import Column, Integer, String, Text, TIMESTAMP, ForeignKey, REAL, BOOLEAN, Date
from sqlalchemy.orm import DeclarativeBase, relationship
from sqlalchemy.sql import func

class Base(DeclarativeBase):
    pass

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())

    notes = relationship("Note", back_populates="user", cascade="all, delete-orphan")
    libraries = relationship("Library", back_populates="user", cascade="all, delete-orphan")
    flashcards = relationship("Flashcard", back_populates="user", cascade="all, delete-orphan")
    study_records = relationship("StudyRecord", back_populates="user", cascade="all, delete-orphan")
    study_plan = relationship("StudyPlan", back_populates="user", uselist=False, cascade="all, delete-orphan")
    ai_config = relationship("AIConfig", back_populates="user", uselist=False, cascade="all, delete-orphan")
    extraction_jobs = relationship("ExtractionJob", back_populates="user", cascade="all, delete-orphan")
    daily_tasks = relationship("DailyTask", back_populates="user", cascade="all, delete-orphan")
    algorithm_settings = relationship("AlgorithmSettings", back_populates="user", uselist=False, cascade="all, delete-orphan")

class Library(Base):
    __tablename__ = "libraries"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    daily_new_cards = Column(Integer, nullable=True)
    daily_review_limit = Column(Integer, nullable=True)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    updated_at = Column(TIMESTAMP(timezone=True), server_default=func.now(), onupdate=func.now())

    user = relationship("User", back_populates="libraries")
    flashcards = relationship("Flashcard", back_populates="library", cascade="all, delete-orphan")
    daily_tasks = relationship("DailyTask", back_populates="library", cascade="all, delete-orphan")

class Note(Base):
    __tablename__ = "notes"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(255), nullable=False)
    content = Column(Text, nullable=False)
    source_path = Column(String(500), nullable=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    library_id = Column(Integer, ForeignKey("libraries.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    updated_at = Column(TIMESTAMP(timezone=True), server_default=func.now(), onupdate=func.now())

    user = relationship("User", back_populates="notes")
    library = relationship("Library")
    extraction_jobs = relationship("ExtractionJob", back_populates="note")

class Flashcard(Base):
    __tablename__ = "flashcards"

    id = Column(Integer, primary_key=True, index=True)
    front = Column(Text, nullable=False)
    back = Column(Text, nullable=False)
    library_id = Column(Integer, ForeignKey("libraries.id", ondelete="CASCADE"), nullable=False)
    difficulty = Column(Integer, default=0)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())

    library = relationship("Library", back_populates="flashcards")
    user = relationship("User", back_populates="flashcards")
    study_records = relationship("StudyRecord", back_populates="flashcard", cascade="all, delete-orphan")

class StudyRecord(Base):
    __tablename__ = "study_records"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    flashcard_id = Column(Integer, ForeignKey("flashcards.id", ondelete="CASCADE"), nullable=False)
    interval_days = Column(Integer, default=0)
    ease_factor = Column(REAL, default=2.5)
    repetitions = Column(Integer, default=0)
    next_review_at = Column(TIMESTAMP(timezone=True), nullable=True)
    last_review_at = Column(TIMESTAMP(timezone=True), nullable=True)

    user = relationship("User", back_populates="study_records")
    flashcard = relationship("Flashcard", back_populates="study_records")

class StudyPlan(Base):
    __tablename__ = "study_plans"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), unique=True, nullable=False)
    name = Column(String(100), default="default plan")
    daily_new_cards = Column(Integer, default=20)
    daily_review_limit = Column(Integer, default=100)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    updated_at = Column(TIMESTAMP(timezone=True), server_default=func.now(), onupdate=func.now())

    user = relationship("User", back_populates="study_plan")

class DailyTask(Base):
    __tablename__ = "daily_tasks"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    library_id = Column(Integer, ForeignKey("libraries.id", ondelete="CASCADE"), nullable=True)
    date = Column(Date, nullable=False)
    plan_id = Column(Integer, ForeignKey("study_plans.id"), nullable=True)
    new_cards_target = Column(Integer, default=20)
    new_cards_done = Column(Integer, default=0)
    review_target = Column(Integer, default=100)
    review_done = Column(Integer, default=0)
    completed = Column(BOOLEAN, default=False)

    user = relationship("User", back_populates="daily_tasks")
    library = relationship("Library", back_populates="daily_tasks")

class AIConfig(Base):
    __tablename__ = "ai_configs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), unique=True, nullable=False)
    provider = Column(String(50), default="kimi")
    base_url = Column(String(255), default="https://api.moonshot.cn/v1")
    api_key_encrypted = Column(Text, nullable=True)
    model = Column(String(100), default="moonshot-v1-8k")
    temperature = Column(REAL, default=0.3)
    max_tokens = Column(Integer, default=2048)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    updated_at = Column(TIMESTAMP(timezone=True), server_default=func.now(), onupdate=func.now())

    user = relationship("User", back_populates="ai_config")

class AlgorithmSettings(Base):
    __tablename__ = "algorithm_settings"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), unique=True, nullable=False)
    new_card_easy_interval = Column(Integer, default=3)
    new_card_hard_interval = Column(Integer, default=1)
    second_repetition_interval = Column(Integer, default=6)
    min_ease_factor = Column(REAL, default=1.3)
    initial_ease_factor = Column(REAL, default=2.5)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    updated_at = Column(TIMESTAMP(timezone=True), server_default=func.now(), onupdate=func.now())

    user = relationship("User", back_populates="algorithm_settings")

class ExtractionJob(Base):
    __tablename__ = "extraction_jobs"

    id = Column(Integer, primary_key=True, index=True)
    note_id = Column(Integer, ForeignKey("notes.id", ondelete="SET NULL"), nullable=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    status = Column(String(20), default="pending")
    flashcard_count = Column(Integer, default=0)
    error_message = Column(Text, nullable=True)
    progress_message = Column(Text, nullable=True)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    completed_at = Column(TIMESTAMP(timezone=True), nullable=True)

    note = relationship("Note", back_populates="extraction_jobs")
    user = relationship("User", back_populates="extraction_jobs")
