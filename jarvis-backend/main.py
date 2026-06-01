"""Jarvis Planner Backend — Google Calendar, Gmail, Auth, AI-proxy."""
import os
import json
import logging
from datetime import datetime, timedelta
from typing import Optional, List
from pathlib import Path

from dotenv import load_dotenv
load_dotenv(Path(__file__).parent / ".env")

from fastapi import FastAPI, Request, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse, HTMLResponse
from pydantic import BaseModel

import google_auth
from google_services import GoogleCalendarService, GmailService

# ---------------------------------------------------------------------------
# LLM configuration (Cloud GPT + Ollama)
# ---------------------------------------------------------------------------

CL0UD_LLM_API_KEY = os.getenv("JARVIS_CLOUD_LLM_API_KEY")  # e.g. OpenAI key
CL0UD_LLM_MODEL = os.getenv("JARVIS_CLOUD_LLM_MODEL", "gpt-4.1-mini")
CL0UD_LLM_BASE_URL = os.getenv("JARVIS_CLOUD_LLM_BASE_URL", "https://api.openai.com/v1")


def _cloud_llm_enabled() -> bool:
    """Return True if Cloud LLM is configured via environment variables."""
    return bool(CL0UD_LLM_API_KEY)


async def _cloud_chat(messages: list, json_mode: bool = False, timeout: float = 60.0) -> Optional[str]:
    """Call Cloud LLM (OpenAI-compatible) and return assistant content string.

    messages: list of {"role", "content"} dicts.
    If json_mode=True, we request structured JSON response.
    """
    if not _cloud_llm_enabled():
        return None

    import httpx

    headers = {
        "Authorization": f"Bearer {CL0UD_LLM_API_KEY}",
        "Content-Type": "application/json",
    }
    body: dict = {
        "model": CL0UD_LLM_MODEL,
        "messages": messages,
        "temperature": 0.2,
    }
    if json_mode:
        # JSON schema-agnostic: just ask for a JSON object
        body["response_format"] = {"type": "json_object"}

    async with httpx.AsyncClient(timeout=timeout, base_url=CL0UD_LLM_BASE_URL) as client:
        r = await client.post("/chat/completions", json=body, headers=headers)
        r.raise_for_status()
        data = r.json()
        choices = data.get("choices") or []
        if not choices:
            return None
        msg = choices[0].get("message") or {}
        content = msg.get("content")
        return content.strip() if isinstance(content, str) else None

# ---------------------------------------------------------------------------
# App & logging
# ---------------------------------------------------------------------------

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("jarvis")

# ---------------------------------------------------------------------------
# Environment & security configuration
# ---------------------------------------------------------------------------

# "production" enables stricter defaults (no interactive docs, no wildcard CORS).
JARVIS_ENV = os.getenv("JARVIS_ENV", "development").lower()
IS_PRODUCTION = JARVIS_ENV in ("production", "prod")

# Comma-separated list of allowed browser origins. In development we default to a
# permissive wildcard for convenience; in production an explicit list is required.
# Native app clients do not send an Origin header, so an empty list does not break them.
_origins_env = os.getenv("JARVIS_ALLOWED_ORIGINS", "").strip()
if _origins_env:
    ALLOWED_ORIGINS = [o.strip() for o in _origins_env.split(",") if o.strip()]
elif IS_PRODUCTION:
    ALLOWED_ORIGINS = []  # Lock down: no cross-origin browser access unless configured.
else:
    ALLOWED_ORIGINS = ["*"]

# Interactive API docs leak the full schema; keep them off in production unless opted in.
_enable_docs = os.getenv("JARVIS_ENABLE_DOCS", "0" if IS_PRODUCTION else "1") == "1"

app = FastAPI(
    title="Jarvis Backend",
    version="2.0.0",
    docs_url="/docs" if _enable_docs else None,
    redoc_url="/redoc" if _enable_docs else None,
    openapi_url="/openapi.json" if _enable_docs else None,
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

REDIRECT_URI = os.getenv("GOOGLE_REDIRECT_URI", "http://localhost:8000/auth/callback")

# ---------------------------------------------------------------------------
# API Key authentication
# ---------------------------------------------------------------------------

API_KEY = os.getenv("JARVIS_API_KEY")  # Set to enable; leave empty to disable
if IS_PRODUCTION and not API_KEY:
    log.warning(
        "JARVIS_API_KEY is not set in production — all endpoints are UNAUTHENTICATED. "
        "Set JARVIS_API_KEY to protect personal data."
    )

# Paths that do NOT require an API key. Docs paths are included only when docs are enabled.
_PUBLIC_PATHS = {"/health", "/auth/callback"}
if _enable_docs:
    _PUBLIC_PATHS |= {"/docs", "/openapi.json", "/redoc"}


def _check_api_key(request: Request) -> None:
    """Verify API key if JARVIS_API_KEY env var is set."""
    if not API_KEY:
        return  # No key configured — skip check
    key = request.headers.get("X-API-Key") or request.query_params.get("api_key")
    if key != API_KEY:
        raise HTTPException(403, detail="Invalid or missing API key")


@app.middleware("http")
async def api_key_middleware(request: Request, call_next):
    """Global middleware: enforce the API key on all non-public endpoints.

    Note: there is intentionally no localhost bypass. A loopback exemption is unsafe
    behind a reverse proxy (where every request appears to originate from 127.0.0.1)
    and would silently disable authentication for the entire API.
    """
    path = request.url.path
    if path not in _PUBLIC_PATHS:
        _check_api_key(request)
    response = await call_next(request)
    return response


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

class CalendarEventUpdate(BaseModel):
    summary: str = None
    description: str = None
    start: str = None
    end: str = None
    timeZone: str = "Europe/Moscow"

class GmailDraft(BaseModel):
    to: str
    subject: str
    body: str

class GmailReply(BaseModel):
    message_id: str
    body: str

class AISummarizePayload(BaseModel):
    text: str
    max_sentences: int = 3

class AIGenerateReplyPayload(BaseModel):
    original_text: str
    instruction: str = ""
    tone: str = "professional"


# ---------------------------------------------------------------------------
# Healthcheck
# ---------------------------------------------------------------------------

@app.get("/health")
async def health():
    return {
        "status": "ok",
        "version": "2.0.0",
        "ollama": await _check_ollama(),
        "llm": _cloud_llm_enabled() or bool(GEMINI_API_KEY) or await _check_ollama(),
        "gemini": bool(GEMINI_API_KEY),
        "cloud_llm": _cloud_llm_enabled(),
    }


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


@app.put("/calendar/events/{event_id}")
async def update_calendar_event(event_id: str, event: CalendarEventUpdate):
    creds = google_auth.get_credentials()
    if not creds:
        raise HTTPException(401, detail="Not authorized")
    try:
        updates = {}
        if event.summary is not None:
            updates["summary"] = event.summary
        if event.description is not None:
            updates["description"] = event.description
        if event.start is not None:
            updates["start"] = event.start
        if event.end is not None:
            updates["end"] = event.end
        if event.timeZone:
            updates["timeZone"] = event.timeZone
        cal = GoogleCalendarService(creds)
        return cal.update_event(event_id, updates)
    except Exception as e:
        log.error(f"Calendar update error: {e}")
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


@app.delete("/mail/messages/{message_id}")
async def delete_mail_message(message_id: str):
    creds = google_auth.get_credentials()
    if not creds:
        raise HTTPException(401, detail="Not authorized")
    try:
        gmail = GmailService(creds)
        gmail.trash_message(message_id)
        return {"status": "trashed", "id": message_id}
    except Exception as e:
        log.error(f"Gmail trash error: {e}")
        raise HTTPException(500, detail=str(e))


@app.post("/mail/messages/{message_id}/read")
async def mark_mail_read(message_id: str):
    creds = google_auth.get_credentials()
    if not creds:
        raise HTTPException(401, detail="Not authorized")
    try:
        gmail = GmailService(creds)
        gmail.mark_as_read(message_id)
        return {"status": "read", "id": message_id}
    except Exception as e:
        log.error(f"Gmail mark read error: {e}")
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
# Gemini text generation helper (used by AI endpoints + meal analysis)
# ---------------------------------------------------------------------------

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")


async def _gemini_chat(messages: list, json_mode: bool = False, timeout: float = 30.0) -> Optional[str]:
    """Call Gemini API for text generation. Returns response text or None."""
    if not GEMINI_API_KEY:
        return None

    import httpx

    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={GEMINI_API_KEY}"

    # Convert messages to Gemini format
    contents = []
    system_text = None
    for msg in messages:
        role = msg.get("role", "user")
        content = msg.get("content", "")
        if role == "system":
            system_text = content
            continue
        gemini_role = "model" if role == "assistant" else "user"
        contents.append({"role": gemini_role, "parts": [{"text": content}]})

    # If there's a system prompt, prepend it to first user message
    if system_text and contents:
        first_text = contents[0]["parts"][0]["text"]
        contents[0]["parts"][0]["text"] = system_text + "\n\n" + first_text

    payload = {
        "contents": contents,
        "generationConfig": {
            "temperature": 0.3,
            "maxOutputTokens": 2000,
        },
    }
    if json_mode:
        payload["generationConfig"]["responseMimeType"] = "application/json"

    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            r = await client.post(url, json=payload)
            r.raise_for_status()
            data = r.json()

        text = ""
        for candidate in data.get("candidates", []):
            for part in candidate.get("content", {}).get("parts", []):
                text += part.get("text", "")
        return text.strip() if text.strip() else None
    except Exception as e:
        log.warning(f"Gemini text generation error: {e}")
        return None


# ---------------------------------------------------------------------------
# NUTRITION — Meal photo analysis (Gemini → heuristic fallback)
# ---------------------------------------------------------------------------


@app.post("/analyze-meal")
async def analyze_meal(request: Request):
    """Analyze food photo: Gemini vision → heuristic fallback.

    Accepts raw image bytes (Content-Type: image/*) or base64 JSON {"image": "..."}.
    Returns: {"title": "...", "calories": N}
    """
    content_type = request.headers.get("content-type", "")
    image_bytes: Optional[bytes] = None

    if "json" in content_type:
        body = await request.json()
        import base64 as b64mod
        raw = body.get("image", "")
        if raw:
            # Strip data URI prefix if present
            if "," in raw:
                raw = raw.split(",", 1)[1]
            image_bytes = b64mod.b64decode(raw)
    else:
        image_bytes = await request.body()

    if not image_bytes or len(image_bytes) < 100:
        return {"title": "\u0411\u043b\u044e\u0434\u043e", "calories": 0}

    # 1) Try Gemini Vision API
    if GEMINI_API_KEY:
        try:
            result = await _analyze_meal_gemini(image_bytes)
            if result:
                return result
        except Exception as e:
            log.warning(f"Gemini meal analysis failed: {e}")

    # 2) Try Cloud LLM with base64 description (text-only fallback)
    if _cloud_llm_enabled():
        try:
            result = await _analyze_meal_cloud_llm(len(image_bytes))
            if result:
                return result
        except Exception as e:
            log.warning(f"Cloud LLM meal analysis failed: {e}")

    # 3) Heuristic fallback based on image size
    return _analyze_meal_heuristic(len(image_bytes))


async def _analyze_meal_gemini(image_bytes: bytes) -> Optional[dict]:
    """Use Google Gemini (multimodal) to analyze food photo."""
    import httpx
    import base64 as b64mod

    b64_image = b64mod.b64encode(image_bytes).decode("utf-8")

    # Detect MIME type from magic bytes
    mime = "image/jpeg"
    if image_bytes[:4] == b'\x89PNG':
        mime = "image/png"
    elif image_bytes[:4] == b'RIFF':
        mime = "image/webp"

    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={GEMINI_API_KEY}"

    payload = {
        "contents": [{
            "parts": [
                {"text": "What dish is shown in this photo? Reply with ONLY a JSON object: {\"title\": \"dish name in Russian\", \"calories\": estimated_calories_number}. Be concise. If unsure, give best estimate."},
                {"inline_data": {"mime_type": mime, "data": b64_image}},
            ]
        }],
        "generationConfig": {"temperature": 0.1, "maxOutputTokens": 200},
    }

    async with httpx.AsyncClient(timeout=30.0) as client:
        r = await client.post(url, json=payload)
        r.raise_for_status()
        data = r.json()

    text = ""
    for candidate in data.get("candidates", []):
        for part in candidate.get("content", {}).get("parts", []):
            text += part.get("text", "")

    text = text.strip()
    # Extract JSON from response
    if "{" in text:
        json_str = text[text.index("{"):text.rindex("}") + 1]
        parsed = json.loads(json_str)
        title = parsed.get("title", "\u0411\u043b\u044e\u0434\u043e")
        calories = int(parsed.get("calories", 0))
        log.info(f"Gemini meal: {title} ({calories} kcal)")
        return {"title": title, "calories": calories, "source": "gemini"}

    return None


async def _analyze_meal_cloud_llm(size_bytes: int) -> Optional[dict]:
    """Ask Cloud LLM for a rough estimate (no image, just size hint)."""
    prompt = f"User uploaded a food photo ({size_bytes // 1024} KB). Without seeing it, give a reasonable generic meal estimate. Reply ONLY as JSON: {{\"title\": \"name\", \"calories\": number}}"
    text = await _cloud_chat(
        [{"role": "user", "content": prompt}],
        json_mode=True,
        timeout=15.0,
    )
    if text and "{" in text:
        parsed = json.loads(text)
        return {"title": parsed.get("title", "\u0411\u043b\u044e\u0434\u043e"), "calories": int(parsed.get("calories", 300)), "source": "cloud"}
    return None


def _analyze_meal_heuristic(size_bytes: int) -> dict:
    """Heuristic fallback based on image file size."""
    size_kb = size_bytes / 1024
    if size_kb < 50:
        return {"title": "\u041b\u0451\u0433\u043a\u0430\u044f \u0437\u0430\u043a\u0443\u0441\u043a\u0430", "calories": 150, "source": "heuristic"}
    if size_kb < 200:
        return {"title": "\u041e\u0441\u043d\u043e\u0432\u043d\u043e\u0435 \u0431\u043b\u044e\u0434\u043e", "calories": 400, "source": "heuristic"}
    return {"title": "\u041e\u0431\u0438\u043b\u044c\u043d\u044b\u0439 \u043f\u0440\u0438\u0451\u043c \u043f\u0438\u0449\u0438", "calories": 600, "source": "heuristic"}


# ---------------------------------------------------------------------------
# LLM — AI proxy (Ollama + heuristic fallback)
# ---------------------------------------------------------------------------

@app.post("/llm/plan")
async def llm_plan(payload: PlanPayload):
    tasks = payload.tasks
    total = len(tasks)
    completed = sum(1 for t in tasks if t.isCompleted)
    # 1) Cloud LLM (если настроен)
    cloud_result = await _ask_cloud_plan(tasks)
    if cloud_result:
        return {"advice": cloud_result, "source": "cloud"}

    # 2) Gemini fallback
    if GEMINI_API_KEY:
        task_list = "\n".join(
            f"- {'[✓]' if t.isCompleted else '[ ]'} {t.title}" + (f" ({t.notes})" if t.notes else "")
            for t in tasks
        )
        gemini_result = await _gemini_chat([
            {"role": "system", "content": "Ты — AI-планировщик. Дай 3-5 кратких практических советов по планированию дня. Отвечай по-русски."},
            {"role": "user", "content": f"Задачи:\n{task_list}\nВсего: {total}, выполнено: {completed}"},
        ])
        if gemini_result:
            return {"advice": gemini_result, "source": "gemini"}

    # 3) Локальная Ollama
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
    """Unified chat endpoint: Cloud LLM → Gemini → Ollama fallback."""
    body = await request.json()
    messages = body.get("messages") or []

    # 1) Try Cloud LLM first if configured
    if _cloud_llm_enabled():
        try:
            text = await _cloud_chat(messages, json_mode=False, timeout=120.0)
            if text is not None:
                return {"message": {"role": "assistant", "content": text}}
        except Exception as e:  # noqa: BLE001
            log.error(f"Cloud LLM chat error: {e}")

    # 2) Gemini fallback
    if GEMINI_API_KEY:
        try:
            text = await _gemini_chat(messages, json_mode=False, timeout=30.0)
            if text is not None:
                return {"message": {"role": "assistant", "content": text}}
        except Exception as e:  # noqa: BLE001
            log.error(f"Gemini chat error: {e}")

    # 3) Fallback: proxy to local Ollama
    import httpx
    try:
        async with httpx.AsyncClient(timeout=120.0) as client:
            r = await client.post("http://localhost:11434/api/chat", json=body)
            r.raise_for_status()
            return r.json()
    except Exception as e:  # noqa: BLE001
        log.error(f"LLM chat proxy error: {e}")
        raise HTTPException(502, detail=f"AI services unavailable")


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


async def _ask_cloud_plan(tasks: List[Task]) -> Optional[str]:
    """Ask Cloud LLM for planning advice, if configured."""
    if not _cloud_llm_enabled() or not tasks:
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

    messages = [
        {"role": "system", "content": "Ты — Jarvis, личный AI-планировщик."},
        {"role": "user", "content": prompt},
    ]
    try:
        return await _cloud_chat(messages, json_mode=False, timeout=30.0)
    except Exception as e:  # noqa: BLE001
        log.warning(f"Cloud plan request failed: {e}")
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
Пользователь управляет приложением голосом — распознай намерение и выполни действие.

Дата: {current_date}, Время: {datetime.now().strftime('%H:%M')}
Google подключён: {"да" if google_connected else "нет"}

Задачи пользователя:
{tasks_context if tasks_context else 'Нет задач'}

ФОРМАТ ОТВЕТА — строго JSON:
{{"response": "текст для пользователя", "actions": [{{"type": "тип", "params": {{}}}}]}}

Типы actions:
- create_task: {{"title": "...", "date": "ISO-8601", "notes": "...", "priority": "low|medium|high", "folder": "inbox|today", "is_all_day": "true|false"}}
- complete_task: {{"title": "поиск по названию (приблизительно)"}}
- delete_task: {{"title": "поиск по названию"}}
- reschedule_task: {{"title": "...", "new_date": "ISO-8601"}}
- move_task: {{"title": "...", "folder": "inbox|today|scheduled|future|completed"}}
- create_event: {{"summary": "...", "start": "ISO-8601", "end": "ISO-8601"}}
- send_email: {{"to": "...", "subject": "...", "body": "..."}}
- show_calendar: {{"days": 7}}
- show_mail: {{"query": "is:unread", "max_results": 10}}
- advice: {{}}
- none: {{}}

Правила:
1. Если пользователь говорит "создай задачу" — используй create_task. Дату выбирай по контексту (сегодня/завтра/конкретная).
2. Если "выполни"/"сделано"/"готово" — используй complete_task с приблизительным названием.
3. Если "перенеси в"/"переведи во входящие"/"в выполненные" — используй move_task.
4. Если "перенеси на завтра"/"на послезавтра" — используй reschedule_task.
5. Если "покажи почту"/"есть непрочитанные" — используй show_mail.
6. Если "выдержка"/"сводка"/"обзор" — дай подробный обзор задач и ситуации.
7. Всегда давай краткий, полезный response на русском языке.
8. Можно выполнять несколько actions за раз.

Отвечай ТОЛЬКО валидным JSON."""
    # 1) Cloud LLM with JSON output, if configured
    if _cloud_llm_enabled():
        try:
            ai_text = await _cloud_chat(
                [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": message},
                ],
                json_mode=True,
                timeout=60.0,
            )
            if ai_text is None:
                raise RuntimeError("Empty Cloud LLM response")
            try:
                parsed = json.loads(ai_text)
            except json.JSONDecodeError:
                parsed = {"response": ai_text, "actions": []}

            _execute_server_side_actions(parsed)
            return parsed
        except Exception as e:  # noqa: BLE001
            log.error(f"Cloud AI command error, falling back: {e}")

    # 2) Gemini fallback (if GEMINI_API_KEY is set)
    if GEMINI_API_KEY:
        try:
            ai_text = await _gemini_chat(
                [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": message},
                ],
                json_mode=True,
                timeout=30.0,
            )
            if ai_text:
                try:
                    parsed = json.loads(ai_text)
                except json.JSONDecodeError:
                    parsed = {"response": ai_text, "actions": []}
                _execute_server_side_actions(parsed)
                return parsed
        except Exception as e:  # noqa: BLE001
            log.error(f"Gemini AI command error, falling back to Ollama: {e}")

    # 3) Fallback: Ollama JSON chat
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

                _execute_server_side_actions(parsed)
                return parsed
    except Exception as e:  # noqa: BLE001
        log.warning(f"Ollama AI command error: {e}")

    # 4) Heuristic fallback — always return a useful response
    tasks_list = context.get("tasks", [])
    total = len(tasks_list)
    done = sum(1 for t in tasks_list if t.get("isCompleted"))
    if total == 0:
        advice = "Нет задач на сегодня. Добавьте задачи, чтобы Jarvis мог помочь с планированием."
    elif done >= total:
        advice = "Все задачи выполнены! Отличная работа. Можно добавить задачи на завтра."
    elif done / total >= 0.5:
        advice = f"Хороший прогресс: {done}/{total} задач выполнено. Продолжайте в том же духе!"
    else:
        advice = f"Выполнено {done}/{total} задач. Сосредоточьтесь на самых важных."
    return {"response": advice, "actions": [], "source": "heuristic"}


def _execute_server_side_actions(parsed: dict) -> None:
    """Execute calendar/mail actions on the server (shared for all LLMs)."""
    creds = google_auth.get_credentials()
    executed = []

    for action in parsed.get("actions", []) or []:
        atype = action.get("type", "none")
        params = action.get("params", {}) or {}

        if atype == "create_event" and creds:
            try:
                cal = GoogleCalendarService(creds)
                ev = cal.create_event(
                    summary=params.get("summary", ""),
                    start_iso=params.get("start", ""),
                    end_iso=params.get("end", ""),
                )
                executed.append({"type": atype, "status": "success", "event_id": ev.get("id")})
            except Exception as exc:  # noqa: BLE001
                executed.append({"type": atype, "status": "error", "error": str(exc)})

        elif atype == "send_email" and creds:
            try:
                gmail = GmailService(creds)
                gmail.send_message(
                    to=params.get("to", ""),
                    subject=params.get("subject", ""),
                    body=params.get("body", ""),
                )
                executed.append({"type": atype, "status": "success"})
            except Exception as exc:  # noqa: BLE001
                executed.append({"type": atype, "status": "error", "error": str(exc)})

        elif atype in ("show_calendar", "show_mail") and creds:
            try:
                if atype == "show_calendar":
                    cal = GoogleCalendarService(creds)
                    data = cal.list_events(days_ahead=params.get("days", 7))
                else:
                    gmail = GmailService(creds)
                    data = gmail.list_messages(
                        max_results=params.get("max_results", 10),
                        query=params.get("query", ""),
                    )
                executed.append({"type": atype, "status": "success", "data": data})
            except Exception as exc:  # noqa: BLE001
                executed.append({"type": atype, "status": "error", "error": str(exc)})
        else:
            executed.append({"type": atype, "status": "pending", "params": params})

    parsed["executed"] = executed


# ---------------------------------------------------------------------------
# AI DIGEST — Aggregated summary from all sources
# ---------------------------------------------------------------------------

class DigestPayload(BaseModel):
    context: str

@app.post("/ai/digest")
async def ai_digest(payload: DigestPayload):
    """Генерирует AI-выдержку по контексту (задачи, календарь, почта, мессенджеры)."""
    context = payload.context

    # Enrich with live data from Google services if authorized
    creds = google_auth.get_credentials()
    extra_context = ""
    if creds:
        try:
            cal = GoogleCalendarService(creds)
            events = cal.list_events(days_ahead=3, max_results=10)
            if events:
                extra_context += "\n\n📅 LIVE CALENDAR DATA:\n"
                for ev in events[:10]:
                    extra_context += f"- {ev.get('title', '?')} @ {ev.get('startDate', '?')}\n"
        except Exception as e:
            log.warning(f"Digest calendar fetch: {e}")

        try:
            gmail = GmailService(creds)
            msgs = gmail.list_messages(max_results=8, query="is:unread")
            if msgs:
                extra_context += "\n📧 LIVE UNREAD MAIL:\n"
                for m in msgs[:8]:
                    extra_context += f"- {m.get('from', '?')}: {m.get('subject', '?')}\n"
        except Exception as e:
            log.warning(f"Digest mail fetch: {e}")

    full_context = context + extra_context

    # Enrich with messenger data if configured
    try:
        if _telegram.selected_chat_ids:
            tg_text = await _telegram.generate_digest_text(hours=24)
            if tg_text and not tg_text.startswith("Нет новых"):
                full_context += f"\n\n💬 TELEGRAM:\n{tg_text[:3000]}"
    except Exception as e:
        log.warning(f"Digest Telegram fetch: {e}")

    system_prompt = """Ты — Jarvis, личный AI-ассистент. Сделай краткую структурированную выдержку.

Формат:
🎯 Главное сейчас (1-2 предложения)
📋 Задачи — статус, приоритеты, просрочки
📅 Календарь — ближайшие важные события
📧 Почта — что требует внимания
💬 Мессенджеры (если есть)
⏰ Рекомендация на ближайший час

Будь конкретен и полезен. Отвечай по-русски."""

    # 1) Cloud LLM, если доступен
    if _cloud_llm_enabled():
        try:
            text = await _cloud_chat(
                [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": full_context},
                ],
                json_mode=False,
                timeout=60.0,
            )
            if text:
                return {"summary": text}
        except Exception as e:  # noqa: BLE001
            log.error(f"Cloud digest error, falling back: {e}")

    # 2) Gemini fallback
    if GEMINI_API_KEY:
        try:
            text = await _gemini_chat(
                [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": full_context},
                ],
                timeout=30.0,
            )
            if text:
                return {"summary": text}
        except Exception as e:  # noqa: BLE001
            log.error(f"Gemini digest error: {e}")

    # 3) Fallback: Ollama
    import httpx
    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            r = await client.post("http://localhost:11434/api/chat", json={
                "model": "llama3.2",
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": full_context},
                ],
                "stream": False,
            })
            if r.status_code == 200:
                text = r.json().get("message", {}).get("content", "").strip()
                return {"summary": text if text else "Не удалось сгенерировать выдержку."}
            raise HTTPException(502, detail="Ollama error")
    except httpx.ConnectError:
        # Fallback: return raw context
        return {"summary": f"⚠️ Ollama недоступна. Сырые данные:\n\n{full_context[:2000]}"}
    except Exception as e:  # noqa: BLE001
        log.error(f"AI digest error: {e}")
        raise HTTPException(500, detail=str(e))


# ---------------------------------------------------------------------------
# INTEGRATIONS — Telegram (Telethon MTProto)
# ---------------------------------------------------------------------------

from telegram_service import TelegramService

_telegram = TelegramService()


class TelegramSendCodePayload(BaseModel):
    phone: str

class TelegramApiCredentialsPayload(BaseModel):
    api_id: int
    api_hash: str

class TelegramAuthCompletePayload(BaseModel):
    code: str
    phone_code_hash: str
    password: Optional[str] = None

class ChatSelectPayload(BaseModel):
    chat_ids: List  # List[int] for Telegram


# --- Telegram Endpoints ---

@app.get("/integrations/telegram/status")
async def telegram_status():
    """Current status of Telegram integration."""
    return _telegram.status


@app.post("/integrations/telegram/api-credentials")
async def telegram_save_api_credentials(payload: TelegramApiCredentialsPayload):
    """Save Telegram API ID + Hash (one-time setup from my.telegram.org)."""
    return _telegram.save_api_credentials(payload.api_id, payload.api_hash)


@app.post("/integrations/telegram/configure")
async def telegram_configure(payload: TelegramSendCodePayload):
    """Save phone and send verification code (single step)."""
    return await _telegram.send_code(payload.phone)


@app.post("/integrations/telegram/auth/send-code")
async def telegram_send_code(payload: TelegramSendCodePayload):
    """Send verification code to the phone number."""
    return await _telegram.send_code(payload.phone)


@app.post("/integrations/telegram/auth/start")
async def telegram_auth_start():
    """Legacy: start auth (requires prior configure call)."""
    tg = _telegram._config.get("telegram", {})
    phone = tg.get("phone")
    if not phone:
        return {"status": "error", "error": "Not configured"}
    return await _telegram.send_code(phone)


@app.post("/integrations/telegram/auth/complete")
async def telegram_auth_complete(payload: TelegramAuthCompletePayload):
    """Complete Telegram auth with the verification code."""
    return await _telegram.complete_auth(
        code=payload.code,
        phone_code_hash=payload.phone_code_hash,
        password=payload.password,
    )


@app.get("/integrations/telegram/chats")
async def telegram_list_chats(limit: int = Query(50, ge=1, le=200)):
    """List user's Telegram chats for selection."""
    chats = await _telegram.list_chats(limit=limit)
    if not chats:
        raise HTTPException(401, detail="Telegram not authorized. Complete auth first.")
    return {"chats": chats}


@app.get("/integrations/telegram/chats/search")
async def telegram_search_chats(q: str = Query("", min_length=1, max_length=200), limit: int = Query(50, ge=1, le=200)):
    """Search user's Telegram chats by name/title."""
    chats = await _telegram.search_chats(query=q, limit=limit)
    return {"chats": chats}


@app.post("/integrations/telegram/chats/select")
async def telegram_select_chats(payload: ChatSelectPayload):
    """Save which Telegram chats to monitor."""
    _telegram.set_selected_chats([int(cid) for cid in payload.chat_ids])
    return {"status": "ok", "selected_count": len(payload.chat_ids)}


@app.get("/integrations/telegram/digest")
async def telegram_digest(hours: int = Query(24, ge=1, le=168)):
    """Get digest from selected Telegram chats, summarized by LLM."""
    if not _telegram.selected_chat_ids:
        return {"summary": "Нет выбранных чатов Telegram. Выберите чаты в настройках."}

    raw_text = await _telegram.generate_digest_text(hours=hours)
    if raw_text.startswith("Нет новых"):
        return {"summary": raw_text}

    # Summarize via LLM
    summary = await _summarize_messenger_digest("Telegram", raw_text)
    return {"summary": summary}


@app.post("/integrations/telegram/disconnect")
async def telegram_disconnect():
    """Logout and clear Telegram session."""
    await _telegram.disconnect()
    return {"status": "disconnected"}


# --- Shared: LLM summarization for messenger digests ---

async def _summarize_messenger_digest(source: str, raw_text: str) -> str:
    """Summarize messenger messages via Cloud LLM → Ollama → raw fallback."""
    system_prompt = f"""Ты — Jarvis, AI-ассистент. Проанализируй сообщения из {source} и сделай краткую выдержку.

Формат:
1. Ключевые темы и обсуждения (коротко)
2. Что требует внимания или ответа
3. Важные договорённости или решения
4. Общее настроение / активность

Правила:
- Будь конкретен, упоминай имена и темы
- Группируй по чатам если их несколько
- Игнорируй спам, стикеры, мелкие реплики
- Отвечай по-русски, кратко и полезно"""

    # 1) Cloud LLM
    if _cloud_llm_enabled():
        try:
            text = await _cloud_chat(
                [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": raw_text[:8000]},
                ],
                json_mode=False,
                timeout=90.0,
            )
            if text:
                return text
        except Exception as e:  # noqa: BLE001
            log.warning(f"Cloud LLM summarization for {source} failed: {e}")

    # 2) Fallback: Ollama
    import httpx
    try:
        async with httpx.AsyncClient(timeout=90.0) as client:
            r = await client.post("http://localhost:11434/api/chat", json={
                "model": "llama3.2",
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": raw_text[:8000]},  # Limit context size
                ],
                "stream": False,
            })
            if r.status_code == 200:
                text = r.json().get("message", {}).get("content", "").strip()
                return text if text else f"Не удалось сгенерировать выдержку {source}."
    except Exception as e:  # noqa: BLE001
        log.warning(f"LLM summarization for {source} failed: {e}")

    # 3) Fallback: return truncated raw text
    return f"⚠️ LLM недоступна. Сырые данные {source}:\n\n{raw_text[:2000]}"


# ---------------------------------------------------------------------------
# AI CONTEXT SEARCH — Cross-source search
# ---------------------------------------------------------------------------

class ContextSearchPayload(BaseModel):
    query: str
    lookback_days: int = 30
    sources: dict = {}


@app.post("/ai/context-search")
async def ai_context_search(payload: ContextSearchPayload):
    """Search across all connected sources (calendar, mail, Telegram).

    Returned JSON structure matches what AIContextEngine expects on the client.
    """

    query = (payload.query or "").strip().lower()
    lookback = max(1, min(payload.lookback_days, 90))

    results = {
        "calendar_matches": [],
        "mail_matches": [],
        "telegram_matches": [],
    }

    if not query:
        return results

    creds = google_auth.get_credentials()

    # Calendar search (Google Calendar)
    if payload.sources.get("calendar", True) and creds:
        try:
            cal = GoogleCalendarService(creds)
            events = cal.list_events(days_ahead=lookback, max_results=100)
            for ev in events:
                text = " ".join(
                    [
                        str(ev.get("title", "")),
                        str(ev.get("notes") or ""),
                        str(ev.get("location") or ""),
                    ]
                ).lower()
                if query in text:
                    results["calendar_matches"].append(
                        {
                            "id": ev.get("id", ""),
                            "title": ev.get("title", ""),
                            "date": ev.get("startDate", "") or "",
                            "attendees": [],  # Not available in current wrapper
                            "notes": ev.get("notes") or "",
                            "relevance": 0.8,
                        }
                    )
        except Exception as e:  # noqa: BLE001
            log.warning(f"Context search calendar error: {e}")

    # Mail search (Gmail)
    if payload.sources.get("mail", True) and creds:
        try:
            gmail = GmailService(creds)
            # Use Gmail's own search syntax with the query string
            messages = gmail.list_messages(max_results=50, query=query)
            for m in messages:
                haystack = " ".join(
                    [
                        str(m.get("subject", "")),
                        str(m.get("from", "")),
                        str(m.get("snippet", "")),
                    ]
                ).lower()
                if query not in haystack:
                    continue
                results["mail_matches"].append(
                    {
                        "id": m.get("id", ""),
                        "subject": m.get("subject", ""),
                        "from": m.get("from", ""),
                        "date": m.get("date", ""),
                        "snippet": m.get("snippet", ""),
                        "relevance": 0.8,
                    }
                )
        except Exception as e:  # noqa: BLE001
            log.warning(f"Context search mail error: {e}")

    # Telegram search (by text in digest)
    if payload.sources.get("telegram", False) and _telegram.selected_chat_ids:
        try:
            raw = await _telegram.generate_digest_text(hours=min(lookback * 24, 168))
            for line in raw.split("\n"):
                if query in line.lower():
                    results["telegram_matches"].append(
                        {
                            "source": "telegram",
                            "chat_name": "Telegram",
                            "sender_name": "",
                            "message_text": line[:300],
                            "date": "",
                            "relevance": 0.7,
                        }
                    )
        except Exception as e:  # noqa: BLE001
            log.warning(f"Context search Telegram error: {e}")

    return results


# ---------------------------------------------------------------------------
# AI MEETING BRIEFING — Cross-source meeting preparation
# ---------------------------------------------------------------------------


class MeetingBriefingPayload(BaseModel):
    meeting_title: str
    meeting_date: str = ""
    participants: List[str] = []
    description: str = ""
    context: str = ""  # Prebuilt context from client (optional)


@app.post("/ai/meeting-briefing")
async def ai_meeting_briefing(payload: MeetingBriefingPayload):
    """Generate structured meeting briefing from all available sources.

    Client usually sends prebuilt `context` (AIContextEngine result). If it's empty,
    backend can still generate briefing based only on title/description.
    """

    base_info = {
        "title": payload.meeting_title,
        "date": payload.meeting_date,
        "participants": payload.participants,
        "description": payload.description,
    }

    context_parts = [
        f"📋 ВСТРЕЧА: {base_info['title']}",
        f"📅 Дата: {base_info['date'] or 'не указана'}",
        f"👥 Участники: {', '.join(base_info['participants']) if base_info['participants'] else 'не указаны'}",
        f"📝 Описание: {base_info['description'] or 'нет'}",
        "",
    ]
    if payload.context:
        context_parts.append("НАЙДЕННАЯ СВЯЗАННАЯ ИНФОРМАЦИЯ:")
        context_parts.append(payload.context)

    full_context = "\n".join(context_parts)

    system_prompt = """Ты — Jarvis, AI-ассистент для подготовки к встречам.
На входе у тебя информация о встрече и связанные данные из календаря, почты и мессенджеров.

Сделай СТРУКТУРИРОВАННУЮ ВЫДЕРЖКУ на русском языке:

1. СУТЬ ВСТРЕЧИ — о чём встреча, кто участвует, какова цель
2. КЛЮЧЕВЫЕ ТЕМЫ — список основных тем и вопросов
3. ИЗ ПЕРЕПИСОК — важные факты, договорённости, открытые вопросы
4. РИСКИ И НЕЯСНОСТИ — что может пойти не так, что нужно уточнить
5. РЕКОМЕНДАЦИИ — что подготовить до встречи, что спросить, на что обратить внимание

Будь конкретен, используй пункты и подзаголовки. Отвечай по-русски."""

    # 1) Cloud LLM
    if _cloud_llm_enabled():
        try:
            text = await _cloud_chat(
                [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": full_context},
                ],
                json_mode=False,
                timeout=90.0,
            )
            if text:
                return {"briefing": text}
        except Exception as e:  # noqa: BLE001
            log.error(f"Meeting briefing Cloud LLM error: {e}")

    # 2) Fallback: Ollama chat
    import httpx
    try:
        async with httpx.AsyncClient(timeout=90.0) as client:
            r = await client.post(
                "http://localhost:11434/api/chat",
                json={
                    "model": "llama3.2",
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": full_context},
                    ],
                    "stream": False,
                },
            )
            if r.status_code == 200:
                text = r.json().get("message", {}).get("content", "").strip()
                return {"briefing": text or "Не удалось сгенерировать брифинг."}
    except Exception as e:  # noqa: BLE001
        log.error(f"Meeting briefing Ollama error: {e}")

    # 3) Fallback: raw context
    return {"briefing": f"LLM unavailable. Raw data:\n{full_context[:3000]}"}


# ---------------------------------------------------------------------------
# AI DELEGATE TASK — Send task to user via messenger
# ---------------------------------------------------------------------------


class DelegateTaskPayload(BaseModel):
    task_title: str
    task_notes: str = ""
    assignee_handle: str
    platform: str = "telegram"  # "telegram" | "whatsapp" (future)


@app.post("/ai/delegate-task")
async def ai_delegate_task(payload: DelegateTaskPayload):
    """Delegate a task to another user via messenger.

    Sends a formatted task message via Telegram (primary) or returns preview
    if the messenger is not authenticated.
    """

    message_preview = (
        f"📋 Вам назначена задача от Jarvis:\n\n"
        f"**{payload.task_title}**\n"
        f"{payload.task_notes}\n\n"
        "Ответьте «принято» для подтверждения."
    )

    if payload.platform == "telegram":
        result = await _telegram.send_message(
            handle=payload.assignee_handle,
            text=message_preview,
        )
        return {
            "status": result.get("status", "error"),
            "platform": "telegram",
            "assignee": payload.assignee_handle,
            "message_preview": message_preview,
            "message_id": result.get("message_id"),
            "error": result.get("error"),
        }

    # WhatsApp and other platforms — not yet implemented
    return {
        "status": "not_implemented",
        "platform": payload.platform,
        "assignee": payload.assignee_handle,
        "message_preview": message_preview,
    }


# ---------------------------------------------------------------------------
# AI — Summarize text / Generate reply
# ---------------------------------------------------------------------------

@app.post("/ai/summarize")
async def ai_summarize(payload: AISummarizePayload):
    """Summarize a given text (email body, article, etc.) using LLM."""
    prompt = (
        f"Summarize the following text in at most {payload.max_sentences} sentences. "
        f"Reply in the same language as the original text.\n\n"
        f"---\n{payload.text}\n---"
    )
    messages = [{"role": "user", "content": prompt}]

    # Try Cloud LLM first
    result = await _cloud_chat(messages, timeout=30.0)
    if result:
        return {"summary": result, "source": "cloud"}

    # Try Gemini
    if GEMINI_API_KEY:
        try:
            result = await _ask_gemini_text(prompt)
            if result:
                return {"summary": result, "source": "gemini"}
        except Exception as e:
            log.warning(f"Gemini summarize failed: {e}")

    # Heuristic: first N sentences
    sentences = [s.strip() for s in payload.text.replace("\n", " ").split(".") if s.strip()]
    summary = ". ".join(sentences[:payload.max_sentences])
    if summary and not summary.endswith("."):
        summary += "."
    return {"summary": summary or payload.text[:200], "source": "heuristic"}


@app.post("/ai/generate-reply")
async def ai_generate_reply(payload: AIGenerateReplyPayload):
    """Generate a reply draft for an email or message."""
    instruction = payload.instruction or "Write a polite, concise reply."
    prompt = (
        f"You are drafting a reply to the following message. "
        f"Tone: {payload.tone}. {instruction}\n\n"
        f"Original message:\n---\n{payload.original_text}\n---\n\n"
        f"Write ONLY the reply text, no greetings header, no signature. "
        f"Reply in the same language as the original."
    )
    messages = [{"role": "user", "content": prompt}]

    result = await _cloud_chat(messages, timeout=30.0)
    if result:
        return {"reply": result, "source": "cloud"}

    if GEMINI_API_KEY:
        try:
            result = await _ask_gemini_text(prompt)
            if result:
                return {"reply": result, "source": "gemini"}
        except Exception as e:
            log.warning(f"Gemini generate-reply failed: {e}")

    return {"reply": "", "source": "none", "error": "No LLM available"}


async def _ask_gemini_text(prompt: str) -> Optional[str]:
    """Call Gemini text-only API."""
    import httpx

    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={GEMINI_API_KEY}"
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"temperature": 0.3, "maxOutputTokens": 1000},
    }
    async with httpx.AsyncClient(timeout=30.0) as client:
        r = await client.post(url, json=payload)
        r.raise_for_status()
        data = r.json()

    text = ""
    for candidate in data.get("candidates", []):
        for part in candidate.get("content", {}).get("parts", []):
            text += part.get("text", "")
    return text.strip() if text.strip() else None
