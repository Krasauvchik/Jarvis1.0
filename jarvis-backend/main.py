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
    # 1) Cloud LLM (если настроен)
    cloud_result = await _ask_cloud_plan(tasks)
    if cloud_result:
        return {"advice": cloud_result, "source": "cloud"}

    # 2) Локальная Ollama
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
    """Unified chat endpoint: Cloud LLM → Ollama fallback."""
    body = await request.json()

    # Try Cloud LLM first if configured
    if _cloud_llm_enabled():
        messages = body.get("messages") or []
        try:
            text = await _cloud_chat(messages, json_mode=False, timeout=120.0)
            if text is not None:
                return {"message": {"role": "assistant", "content": text}}
        except Exception as e:  # noqa: BLE001
            log.error(f"Cloud LLM chat error: {e}")

    # Fallback: proxy to local Ollama
    import httpx
    try:
        async with httpx.AsyncClient(timeout=120.0) as client:
            r = await client.post("http://localhost:11434/api/chat", json=body)
            r.raise_for_status()
            return r.json()
    except Exception as e:  # noqa: BLE001
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
            log.error(f"Cloud AI command error, falling back to Ollama: {e}")

    # 2) Fallback: Ollama JSON chat
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
            raise HTTPException(502, detail="Ollama returned error")
    except httpx.ConnectError:
        raise HTTPException(502, detail="Ollama не запущена. Запустите: ollama serve")
    except Exception as e:  # noqa: BLE001
        log.error(f"AI command error: {e}")
        raise HTTPException(500, detail=str(e))


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

    try:
        if _whatsapp.selected_chat_ids:
            wa_text = await _whatsapp.generate_digest_text()
            if wa_text and not wa_text.startswith("Нет новых"):
                full_context += f"\n\n💬 WHATSAPP:\n{wa_text[:3000]}"
    except Exception as e:
        log.warning(f"Digest WhatsApp fetch: {e}")

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
            log.error(f"Cloud digest error, falling back to Ollama: {e}")

    # 2) Fallback: Ollama
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
from whatsapp_service import WhatsAppService

_telegram = TelegramService()
_whatsapp = WhatsAppService()


class TelegramConfigPayload(BaseModel):
    api_id: int
    api_hash: str
    phone: str

class TelegramAuthCompletePayload(BaseModel):
    code: str
    phone_code_hash: str
    password: Optional[str] = None

class ChatSelectPayload(BaseModel):
    chat_ids: List  # List[int] for Telegram, List[str] for WhatsApp

class WhatsAppConfigPayload(BaseModel):
    instance_id: str
    api_token: str
    base_url: Optional[str] = None


# --- Telegram Endpoints ---

@app.get("/integrations/telegram/status")
async def telegram_status():
    """Current status of Telegram integration."""
    return _telegram.status


@app.post("/integrations/telegram/configure")
async def telegram_configure(payload: TelegramConfigPayload):
    """Save Telegram API credentials (api_id, api_hash, phone)."""
    _telegram.configure(payload.api_id, payload.api_hash, payload.phone)
    return {"status": "configured"}


@app.post("/integrations/telegram/auth/start")
async def telegram_auth_start():
    """Start Telegram auth — sends code to the phone."""
    return await _telegram.start_auth()


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


# --- WhatsApp Endpoints ---

@app.get("/integrations/whatsapp/status")
async def whatsapp_status():
    """Current status of WhatsApp integration."""
    status = _whatsapp.status
    if _whatsapp.is_configured:
        auth = await _whatsapp.check_auth()
        status["auth_status"] = auth.get("status", "unknown")
    return status


@app.post("/integrations/whatsapp/configure")
async def whatsapp_configure(payload: WhatsAppConfigPayload):
    """Save WhatsApp (Green API) credentials."""
    _whatsapp.configure(payload.instance_id, payload.api_token, payload.base_url)
    return {"status": "configured"}


@app.get("/integrations/whatsapp/qr")
async def whatsapp_qr():
    """Get QR code for WhatsApp Web scanning."""
    qr = await _whatsapp.get_qr_code()
    if qr:
        return {"qr": qr}
    raise HTTPException(400, detail="QR not available. Check configuration or already authorized.")


@app.get("/integrations/whatsapp/chats")
async def whatsapp_list_chats():
    """List available WhatsApp chats for selection."""
    chats = await _whatsapp.list_chats()
    if not chats:
        auth = await _whatsapp.check_auth()
        if auth.get("status") != "authorized":
            raise HTTPException(401, detail="WhatsApp not authorized. Scan QR code first.")
        return {"chats": []}
    return {"chats": chats}


@app.post("/integrations/whatsapp/chats/select")
async def whatsapp_select_chats(payload: ChatSelectPayload):
    """Save which WhatsApp chats to monitor."""
    _whatsapp.set_selected_chats([str(cid) for cid in payload.chat_ids])
    return {"status": "ok", "selected_count": len(payload.chat_ids)}


@app.get("/integrations/whatsapp/digest")
async def whatsapp_digest():
    """Get digest from selected WhatsApp chats, summarized by LLM."""
    if not _whatsapp.selected_chat_ids:
        return {"summary": "Нет выбранных чатов WhatsApp. Выберите чаты в настройках."}

    raw_text = await _whatsapp.generate_digest_text()
    if raw_text.startswith("Нет новых"):
        return {"summary": raw_text}

    summary = await _summarize_messenger_digest("WhatsApp", raw_text)
    return {"summary": summary}


@app.post("/integrations/whatsapp/disconnect")
async def whatsapp_disconnect():
    """Disconnect WhatsApp integration."""
    await _whatsapp.disconnect()
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
    """Search across all connected sources (calendar, mail, Telegram, WhatsApp).

    Returned JSON structure matches what AIContextEngine expects on the client.
    """

    query = (payload.query or "").strip().lower()
    lookback = max(1, min(payload.lookback_days, 90))

    results = {
        "calendar_matches": [],
        "mail_matches": [],
        "telegram_matches": [],
        "whatsapp_matches": [],
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

    # WhatsApp search (by text in digest)
    if payload.sources.get("whatsapp", False) and _whatsapp.selected_chat_ids:
        try:
            raw = await _whatsapp.generate_digest_text()
            for line in raw.split("\n"):
                if query in line.lower():
                    results["whatsapp_matches"].append(
                        {
                            "source": "whatsapp",
                            "chat_name": "WhatsApp",
                            "sender_name": "",
                            "message_text": line[:300],
                            "date": "",
                            "relevance": 0.7,
                        }
                    )
        except Exception as e:  # noqa: BLE001
            log.warning(f"Context search WhatsApp error: {e}")

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

    NOTE: Transport-level sending is not fully implemented yet. Endpoint returns
    a preview payload so that client can show status and we can extend it later.
    """

    message_preview = (
        f"📋 Вам назначена задача от Jarvis:\n\n"
        f"*{payload.task_title}*\n"
        f"{payload.task_notes}\n\n"
        "Ответьте «принято» для подтверждения."
    )

    # For now we do not call Telegram/WhatsApp directly (not implemented in services)
    return {
        "status": "not_implemented",
        "platform": payload.platform,
        "assignee": payload.assignee_handle,
        "message_preview": message_preview,
    }
