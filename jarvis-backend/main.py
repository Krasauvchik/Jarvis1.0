"""Jarvis Planner Backend - API для календаря, питания и AI-советов."""
from datetime import datetime, timedelta
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI(title="Jarvis Backend")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])


# --- Models ---

class Task(BaseModel):
    title: str
    notes: str
    date: str
    isCompleted: bool

class PlanPayload(BaseModel):
    tasks: list[Task]


# --- Endpoints ---

@app.get("/health")
async def health():
    return {"status": "ok"}


@app.get("/calendar/events")
async def get_calendar_events():
    """Возвращает события календаря (mock)."""
    now = datetime.utcnow()
    return [
        {"id": "1", "title": "Планирование дня", "notes": None, "startDate": (now + timedelta(hours=1)).isoformat() + "Z"},
        {"id": "2", "title": "Работа над проектом", "notes": None, "startDate": (now + timedelta(hours=3)).isoformat() + "Z"},
    ]


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
