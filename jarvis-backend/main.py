"""Jarvis Planner Backend — Google Calendar, Gmail, Auth, AI-proxy."""
import os
import json
import logging
from datetime import datetime, timedelta
from typing import Optional, List
from pathlib import Path

from fastapi import FastAPI, Request, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse, HTMLResponse
from pydantic import BaseModel

import google_auth
from google_services import GoogleCalendarService, GmailService

# ---------------------------------------------------------------------------
# App & logging
# ---------------------------------------------------------------------------

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("jarvis")

app = FastAPI(title="Jarvis Backend", version="2.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

REDIRECT_URI = os.getenv("GOOGLE_REDIRECT_URI", "http://localhost:8000/auth/callback")


# ---------------------------------------------------------------------------
# Pydantic models
# ---------------------------------------------------------------------------

class Task(BaseModel):
    title: str
    notes: str = ""
    date: str = ""
    isCompleted: bool = False

class PlanPayload(BaseModel):
    tasks: List[Task]

class CalendarEventCreate(BaseModel):
    summary: str
    description: str = ""
    start: str
    end: str
    timeZone: str = "Europe/Moscow"

class GmailDraft(BaseModel):
    to: str
    subject: str
    body: str

class GmailReply(BaseModel):
    message_id: str
    body: str


# ---------------------------------------------------------------------------
# Healthcheck
# ---------------------------------------------------------------------------

@app.get("/health")
async def health():
    return {"status": "ok", "version": "2.0.0", "ollama": await _check_ollama()}


async def _check_ollama() -> bool:
    try:
        import httpx
        async with httpx.AsyncClient(timeout=2.0) as c:
            r = await c.get("http://localhost:11434/api/version")
            return r.status_code == 200
    except Exception:
        return False


# ---------------------------------------------------------------------------
# AUTH — Google OAuth2
# ---------------------------------------------------------------------------

@app.get("/auth/status")
async def auth_status():
    return {"authorized": google_auth.is_authorized()}


@app.get("/auth/google")
async def auth_google():
    url = google_auth.get_auth_url(REDIRECT_URI)
    return RedirectResponse(url)


@app.get("/auth/callback")
async def auth_callback(code: str = Query(...), state: str = Query("")):
    try:
        google_auth.exchange_code_for_token(code, REDIRECT_URI, state)
        log.info("Google OAuth: token saved successfully")
        html = """
        <html><body style="font-family:system-ui;text-align:center;padding:60px">
        <h1>✅ Авторизация прошла успешно!</h1>
        <p>Вернитесь в Jarvis. Это окно можно закрыть.</p>
        <script>setTimeout(()=>window.close(),3000)</script>
        </body></html>"""
        return HTMLResponse(html)
    except Exception as e:
        log.error(f"OAuth callback error: {e}")
        raise HTTPException(400, detail=str(e))


@app.post("/auth/logout")
async def auth_logout():
    token_path = Path(__file__).parent / "token.json"
    if token_path.exists():
        token_path.unlink()
    return {"status": "logged_out"}


# ---------------------------------------------------------------------------
# CALENDAR — Google Calendar API
# ---------------------------------------------------------------------------

@app.get("/calendar/events")
async def get_calendar_events(
    days: int = Query(7, ge=1, le=90),
    max_results: int = Query(50, ge=1, le=250),
):
    creds = google_auth.get_credentials()
    if not creds:
        raise HTTPException(401, detail="Not authorized. Call /auth/google first.")
    try:
        cal = GoogleCalendarService(creds)
        return cal.list_events(days_ahead=days, max_results=max_results)
    except Exception as e:
        log.error(f"Calendar list error: {e}")
        raise HTTPException(500, detail=str(e))


@app.post("/calendar/events")
async def create_calendar_event(event: CalendarEventCreate):
    creds = google_auth.get_credentials()
    if not creds:
        raise HTTPException(401, detail="Not authorized")
    try:
        cal = GoogleCalendarService(creds)
        return cal.create_event(
            summary=event.summary, description=event.description,
            start_iso=event.start, end_iso=event.end, timezone=event.timeZone,
        )
    except Exception as e:
        log.error(f"Calendar create error: {e}")
        raise HTTPException(500, detail=str(e))


@app.delete("/calendar/events/{event_id}")
async def delete_calendar_event(event_id: str):
    creds = google_auth.get_credentials()
    if not creds:
        raise HTTPException(401, detail="Not authorized")
    try:
        cal = GoogleCalendarService(creds)
        cal.delete_event(event_id)
        return {"status": "deleted"}
    except Exception as e:
        log.error(f"Calendar delete error: {e}")
        raise HTTPException(500, detail=str(e))


# ---------------------------------------------------------------------------
# MAIL — Gmail API
# ---------------------------------------------------------------------------

@app.get("/mail/messages")
async def get_mail_messages(
    max_results: int = Query(15, ge=1, le=100),
    query: str = Query("", description="Gmail search query"),
):
    creds = google_auth.get_credentials()
    if not creds:
        raise HTTPException(401, detail="Not authorized. Call /auth/google first.")
    try:
        gmail = GmailService(creds)
        return gmail.list_messages(max_results=max_results, query=query)
    except Exception as e:
        log.error(f"Gmail list error: {e}")
        raise HTTPException(500, detail=str(e))


@app.get("/mail/messages/{message_id}")
async def get_mail_message(message_id: str):
    creds = google_auth.get_credentials()
    if not creds:
        raise HTTPException(401, detail="Not authorized")
    try:
        gmail = GmailService(creds)
        return gmail.get_message(message_id)
    except Exception as e:
        log.error(f"Gmail get error: {e}")
        raise HTTPException(500, detail=str(e))


@app.post("/mail/send")
async def send_mail(draft: GmailDraft):
    creds = google_auth.get_credentials()
    if not creds:
        raise HTTPException(401, detail="Not authorized")
    try:
        gmail = GmailService(creds)
        return gmail.send_message(to=draft.to, subject=draft.subject, body=draft.body)
    except Exception as e:
        log.error(f"Gmail send error: {e}")
        raise HTTPException(500, detail=str(e))


@app.post("/mail/reply")
async def reply_mail(reply: GmailReply):
    creds = google_auth.get_credentials()
    if not creds:
        raise HTTPException(401, detail="Not authorized")
    try:
        gmail = GmailService(creds)
        return gmail.reply_to_message(message_id=reply.message_id, body=reply.body)
    except Exception as e:
        log.error(f"Gmail reply error: {e}")
        raise HTTPException(500, detail=str(e))


# ---------------------------------------------------------------------------
# LLM — AI proxy (Ollama + heuristic fallback)
# ---------------------------------------------------------------------------

@app.post("/llm/plan")
async def llm_plan(payload: PlanPayload):
    tasks = payload.tasks
    total = len(tasks)
    completed = sum(1 for t in tasks if t.isCompleted)

    ollama_result = await _ask_ollama_plan(tasks)
    if ollama_result:
        return {"advice": ollama_result, "source": "ollama"}

    if total == 0:
        return {"advice": "Нет задач. Добавьте цели на день.", "source": "heuristic"}
    ratio = completed / total if total > 0 else 0
    if ratio >= 0.8:
        advice = "Отличный прогресс! Большинство задач выполнено."
    elif ratio >= 0.4:
        advice = "Хороший темп. Разбейте крупные задачи на мелкие."
    else:
        advice = "Много незавершённых задач. Расставьте приоритеты."
    if total > 6:
        advice += " День насыщенный — не забывайте про отдых."
    return {"advice": advice, "source": "heuristic"}


@app.post("/llm/chat")
async def llm_chat(request: Request):
    body = await request.json()
    import httpx
    try:
        async with httpx.AsyncClient(timeout=120.0) as client:
            r = await client.post("http://localhost:11434/api/chat", json=body)
            r.raise_for_status()
            return r.json()
    except Exception as e:
        log.error(f"LLM chat proxy error: {e}")
        raise HTTPException(502, detail=f"Ollama unavailable: {e}")


async def _ask_ollama_plan(tasks: List[Task]) -> Optional[str]:
    if not tasks:
        return None
    task_list = "\n".join(
        f"- {'[✓]' if t.isCompleted else '[ ]'} {t.title}" + (f" ({t.notes})" if t.notes else "")
        for t in tasks[:20]
    )
    prompt = f"""Ты — умный AI-планировщик Jarvis. Проанализируй задачи и дай 3-5 кратких советов по-русски.
Задачи: {task_list}
Выполнено: {sum(1 for t in tasks if t.isCompleted)}/{len(tasks)}
Время: {datetime.now().strftime('%H:%M')}
Советы:"""

    import httpx
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            r = await client.post("http://localhost:11434/api/generate", json={
                "model": "llama3.2", "prompt": prompt, "stream": False,
            })
            if r.status_code == 200:
                text = r.json().get("response", "").strip()
                return text if text else None
    except Exception as e:
        log.warning(f"Ollama plan request failed: {e}")
    return None


# ---------------------------------------------------------------------------
# AI COMMAND — Unified AI endpoint for natural language
# ---------------------------------------------------------------------------

@app.post("/ai/command")
async def ai_command(request: Request):
    """AI обрабатывает команду на естественном языке и выполняет действия."""
    body = await request.json()
    message = body.get("message", "")
    context = body.get("context", {})

    if not message:
        raise HTTPException(400, detail="message is required")

    tasks_context = ""
    if "tasks" in context:
        for t in context["tasks"][:20]:
            status = "[✓]" if t.get("isCompleted") else "[ ]"
            tasks_context += f"- {status} {t.get('title', '')} (дата: {t.get('date', 'нет')})\n"

    current_date = context.get("date", datetime.now().strftime("%Y-%m-%d"))
    google_connected = google_auth.is_authorized()

    system_prompt = f"""Ты — Jarvis, AI-ассистент для планирования. Управляешь задачами, календарём и почтой.

Дата: {current_date}, Время: {datetime.now().strftime('%H:%M')}
Google подключён: {"да" if google_connected else "нет"}

Задачи пользователя:
{tasks_context if tasks_context else 'Нет задач'}

ФОРМАТ ОТВЕТА — строго JSON:
{{"response": "текст для пользователя", "actions": [{{"type": "тип", "params": {{}}}}]}}

Типы actions:
- create_task: {{"title": "...", "date": "ISO-8601", "notes": "...", "priority": "low|medium|high"}}
- complete_task: {{"title": "поиск по названию"}}
- delete_task: {{"title": "поиск по названию"}}
- reschedule_task: {{"title": "...", "new_date": "ISO-8601"}}
- create_event: {{"summary": "...", "start": "ISO-8601", "end": "ISO-8601"}}
- send_email: {{"to": "...", "subject": "...", "body": "..."}}
- show_calendar: {{"days": 7}}
- show_mail: {{"query": "is:unread", "max_results": 10}}
- advice: {{}}
- none: {{}}

Отвечай ТОЛЬКО валидным JSON."""

    import httpx
    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            r = await client.post("http://localhost:11434/api/chat", json={
                "model": "llama3.2",
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": message},
                ],
                "stream": False,
                "format": "json",
            })
            if r.status_code == 200:
                ai_text = r.json().get("message", {}).get("content", "")
                try:
                    parsed = json.loads(ai_text)
                except json.JSONDecodeError:
                    parsed = {"response": ai_text, "actions": []}

                # Execute Google actions server-side
                creds = google_auth.get_credentials()
                executed = []
                for action in parsed.get("actions", []):
                    atype = action.get("type", "none")
                    params = action.get("params", {})

                    if atype == "create_event" and creds:
                        try:
                            cal = GoogleCalendarService(creds)
                            ev = cal.create_event(
                                summary=params.get("summary", ""),
                                start_iso=params.get("start", ""),
                                end_iso=params.get("end", ""),
                            )
                            executed.append({"type": atype, "status": "success", "event_id": ev.get("id")})
                        except Exception as exc:
                            executed.append({"type": atype, "status": "error", "error": str(exc)})

                    elif atype == "send_email" and creds:
                        try:
                            gmail = GmailService(creds)
                            gmail.send_message(to=params.get("to", ""), subject=params.get("subject", ""), body=params.get("body", ""))
                            executed.append({"type": atype, "status": "success"})
                        except Exception as exc:
                            executed.append({"type": atype, "status": "error", "error": str(exc)})

                    elif atype in ("show_calendar", "show_mail") and creds:
                        try:
                            if atype == "show_calendar":
                                cal = GoogleCalendarService(creds)
                                data = cal.list_events(days_ahead=params.get("days", 7))
                            else:
                                gmail = GmailService(creds)
                                data = gmail.list_messages(max_results=params.get("max_results", 10), query=params.get("query", ""))
                            executed.append({"type": atype, "status": "success", "data": data})
                        except Exception as exc:
                            executed.append({"type": atype, "status": "error", "error": str(exc)})
                    else:
                        executed.append({"type": atype, "status": "pending", "params": params})

                parsed["executed"] = executed
                return parsed
            else:
                raise HTTPException(502, detail="Ollama returned error")
    except httpx.ConnectError:
        raise HTTPException(502, detail="Ollama не запущена. Запустите: ollama serve")
    except Exception as e:
        log.error(f"AI command error: {e}")
        raise HTTPException(500, detail=str(e))
