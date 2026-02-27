"""Jarvis Planner Backend - API для календаря, питания и AI-советов."""
import os
from datetime import datetime, timedelta

from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse, JSONResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from google_auth import get_auth_url, exchange_code_for_token, get_credentials, is_authorized

app = FastAPI(title="Jarvis Backend")
static_dir = Path(__file__).parent / "static"
if static_dir.exists():
    app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

# Базовый URL для OAuth (должен совпадать с redirect URI в Google Cloud)
BASE_URL = os.environ.get("BASE_URL", "http://jarvis-app.mooo.com:8000")


# --- Models ---

class Task(BaseModel):
    title: str
    notes: str
    date: str
    isCompleted: bool

class PlanPayload(BaseModel):
    tasks: list[Task]


# --- OAuth ---

@app.get("/auth/status")
async def auth_status():
    """Проверка: авторизован ли пользователь в Google."""
    return {"authorized": is_authorized()}


@app.get("/auth/google")
async def auth_google():
    """Редирект на страницу авторизации Google."""
    from pathlib import Path
    if not (Path(__file__).parent / "credentials.json").exists():
        return {"error": "credentials_missing", "message": "Положите credentials.json в папку jarvis-backend на сервере."}
    redirect_uri = f"{BASE_URL}/auth/callback"
    auth_url = get_auth_url(redirect_uri)
    return RedirectResponse(url=auth_url)


@app.get("/auth/callback")
async def auth_callback(code: str | None = None, error: str | None = None, state: str | None = None):
    """Callback после авторизации в Google."""
    if error:
        return {"error": error, "message": "Авторизация отменена или произошла ошибка."}
    if not code:
        return {"error": "no_code", "message": "Код авторизации не получен."}
    if not state:
        return {"error": "no_state", "message": "Параметр state (code_verifier) отсутствует."}

    redirect_uri = f"{BASE_URL}/auth/callback"
    exchange_code_for_token(code, redirect_uri, code_verifier=state)
    return JSONResponse(
        {"status": "ok", "message": "Авторизация успешна. Используйте /calendar/events и /mail/messages."},
        media_type="application/json; charset=utf-8",
    )


# --- Endpoints ---

@app.get("/")
async def root():
    if (static_dir / "index.html").exists():
        return FileResponse(static_dir / "index.html")
    return {"service": "jarvis-backend", "status": "ok", "docs": "/docs"}


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.get("/calendar/events")
async def get_calendar_events():
    """Возвращает события из Google Calendar или mock, если не авторизован."""
    creds = get_credentials()
    if not creds:
        now = datetime.utcnow()
        return [
            {"id": "mock1", "title": "Планирование дня", "notes": None, "startDate": (now + timedelta(hours=1)).isoformat() + "Z"},
            {"id": "mock2", "title": "Работа над проектом", "notes": None, "startDate": (now + timedelta(hours=3)).isoformat() + "Z"},
        ]

    from googleapiclient.discovery import build
    service = build("calendar", "v3", credentials=creds)
    now = datetime.utcnow()
    time_min = now.isoformat() + "Z"
    time_max = (now + timedelta(days=7)).isoformat() + "Z"

    events_result = service.events().list(
        calendarId="primary",
        timeMin=time_min,
        timeMax=time_max,
        singleEvents=True,
        orderBy="startTime",
    ).execute()
    events = events_result.get("items", [])

    result = []
    for ev in events:
        start = ev.get("start", {}).get("dateTime") or ev.get("start", {}).get("date", "")
        result.append({
            "id": ev.get("id", ""),
            "title": ev.get("summary", "Без названия"),
            "notes": ev.get("description"),
            "startDate": start,
        })
    return result


@app.get("/mail/messages")
async def get_mail_messages(max_results: int = 10):
    """Возвращает последние письма из Gmail."""
    creds = get_credentials()
    if not creds:
        return {"error": "not_authorized", "message": "Сначала авторизуйтесь: GET /auth/google"}

    from googleapiclient.discovery import build
    service = build("gmail", "v1", credentials=creds)
    results = service.users().messages().list(userId="me", maxResults=max_results).execute()
    messages = results.get("messages", [])

    result = []
    for msg_ref in messages:
        msg = service.users().messages().get(userId="me", id=msg_ref["id"]).execute()
        headers = {h["name"]: h["value"] for h in msg.get("payload", {}).get("headers", [])}
        snippet = msg.get("snippet", "")
        result.append({
            "id": msg["id"],
            "subject": headers.get("Subject", ""),
            "from": headers.get("From", ""),
            "date": headers.get("Date", ""),
            "snippet": snippet[:200] + "..." if len(snippet) > 200 else snippet,
        })
    return result


@app.post("/analyze-meal")
async def analyze_meal(request: Request):
    """Анализ фото блюда → название и калории."""
    data = await request.body()
    if not data:
        return {"title": "Блюдо", "calories": 0}
    
    size_kb = len(data) / 1024
    if size_kb < 50:
        return {"title": "Лёгкая закуска", "calories": 150}
    if size_kb < 200:
        return {"title": "Основное блюдо", "calories": 400}
    return {"title": "Обильный приём пищи", "calories": 600}


@app.post("/llm/plan")
async def llm_plan(payload: PlanPayload):
    """Генерирует совет по задачам."""
    tasks = payload.tasks
    total = len(tasks)
    completed = sum(1 for t in tasks if t.isCompleted)
    
    if total == 0:
        return {"advice": "Нет задач. Добавьте цели на день."}
    
    ratio = completed / total
    if ratio >= 0.8:
        advice = "Отличный прогресс! Большинство задач выполнено."
    elif ratio >= 0.4:
        advice = "Хороший темп. Разбейте крупные задачи на мелкие."
    else:
        advice = "Много незавершённых задач. Расставьте приоритеты."
    
    if total > 6:
        advice += " День насыщенный — не забывайте про отдых."
    
    return {"advice": advice}
