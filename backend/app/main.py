from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.exceptions import AppException, app_exception_handler, generic_exception_handler
from app.api import auth, notes, flashcards, study, admin, libraries

app = FastAPI(title="Flash Card API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_exception_handler(AppException, app_exception_handler)
app.add_exception_handler(Exception, generic_exception_handler)

app.include_router(auth.router)
app.include_router(notes.router)
app.include_router(flashcards.router)
app.include_router(libraries.router)
app.include_router(study.router)
app.include_router(admin.router)

@app.get("/health")
async def health_check():
    return {"status": "ok"}
