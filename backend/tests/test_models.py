from app.models.models import Base, User, Note, Flashcard, StudyRecord, StudyPlan, DailyTask, AIConfig, ExtractionJob

def test_user_model():
    assert User.__tablename__ == "users"
    assert hasattr(User, "username")
    assert hasattr(User, "password_hash")
    assert hasattr(User, "notes")

def test_note_model():
    assert Note.__tablename__ == "notes"
    assert hasattr(Note, "title")
    assert hasattr(Note, "content")
    # 闪卡已改为关联 Library，不再直接关联 Note

def test_flashcard_model():
    assert Flashcard.__tablename__ == "flashcards"
    assert hasattr(Flashcard, "front")
    assert hasattr(Flashcard, "back")
    assert hasattr(Flashcard, "study_records")

def test_study_record_model():
    assert StudyRecord.__tablename__ == "study_records"
    assert hasattr(StudyRecord, "interval_days")
    assert hasattr(StudyRecord, "ease_factor")

def test_study_plan_model():
    assert StudyPlan.__tablename__ == "study_plans"
    assert hasattr(StudyPlan, "daily_new_cards")

def test_ai_config_model():
    assert AIConfig.__tablename__ == "ai_configs"
    assert hasattr(AIConfig, "api_key_encrypted")

def test_extraction_job_model():
    assert ExtractionJob.__tablename__ == "extraction_jobs"
    assert hasattr(ExtractionJob, "status")
