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
            else:
                raise HTTPException(502, detail="Ollama error")
    except httpx.ConnectError:
        # Fallback: return raw context
        return {"summary": f"⚠️ Ollama недоступна. Сырые данные:\n\n{full_context[:2000]}"}
    except Exception as e:
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
    """Send raw messenger messages to Ollama for summarization."""
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
    except Exception as e:
        log.warning(f"LLM summarization for {source} failed: {e}")

    # Fallback: return truncated raw text
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
    """Search across all connected sources (calendar, mail, Telegram, WhatsApp)."""
    query = payload.query.lower()
    lookback = payload.lookback_days
    results = {
        "calendar_matches": [],
        "mail_matches": [],
        "telegram_matches": [],
        "whatsapp_matches": [],
    }
    
    creds = google_auth.get_credentials()
    
    # Calendar search
    if payload.sources.get("calendar", True) and creds:
        try:
            cal = GoogleCalendarService(creds)
            events = cal.list_events(days_ahead=lookback, max_r            events = cal.list_events(days_ahead=lookback, max_r    ev.g            events = cal.list_events(days_ahead=lookback, max_r           n",             events = cal.list_events(days_es            events = cal.list_events(days_ahead=lookback, max_r         ery in             events = cal.list_ever() fo         tendee            events = c  resu           ar_matches"].            events = cal.list_              events = cal.list_events(days_ahead=lookback: ev            events = cal.list_events(days_ahead=lookback, max_r            events               events = cal.list_str(            events = cal.list_ev                "notes": ev.get("description", "")[:5            events = ction")            events = cal.l                  events = cal.list_ title else 0.6,
                    })
        except Exception as e:
            log.warning(f"Context search calendar error: {e}")
                search
    if payload.sources.get("mail", True)     if payload.sources.get("mail", True)     if payload.sources.get("mail", True)     if payload.sources.get("mail", True)     if payload.sources.get("mail", True)     if payload.sources.get("mail", True)     if payload.sources.get("mail", True)     if payload.sources.get("mail", True)     if payload.sources.get("mail", True)     if payload.sources.get("mail", True)     if payload.sources.get("mail", True)     if payload.sources.get("mail", True)     if payload.sources.get("mail", True)     if payload.sources.get("mail", True)     if payload.sources.get("mail", True)     if payload.sources.get("mail", True)     if payload.sources.get("mail", True)     if payload.sources.get("mail", True)     if payload.sources.get("mail", True)     if payload.sources.get("mail", True)     if payload.sources.get("mail", True)     if payload.source      if payload.sounes:
    if payload.sources.get( line.lower():
                    results["telegram_matches"].append({
                        "source": "telegram",
                        "chat_name": "Telegram",
                        "sender_name": "",
                        "message_text": line[:300],
                        "date": "",
                        "relevance": 0.7,
                    })
        except Exception as e:
            log.warning(f"Context search Telegram error: {e}")
    
    # WhatsApp search
    if payload.sources.get("whatsapp", False) and _whatsapp.selected_chat_ids:
        try:
            raw = await _whatsapp.generate_digest_text()
            lines = raw.split("\n")
            for line in lines:
                if query in line.lower():
                    results["whatsapp_matches"].append({
                        "source": "whatsapp",
                        "chat_name": "WhatsApp",
                        "sender_name": "",
                        "message_text": line[:300],
                                                                                                             except Exception as e:
            log.warni            log.warni            log.warni    
    return results


# ---------------------------------------------------------------------------
# AI MEETING BRIEFING — Cross-source meeting preparation
# ---------------------------------------------------------------------------

class MeetingBriefingPayload(BaseModel):
    meeting_title: str
    meeting_date: str = ""
    participants: List[str] = []
    description: str = ""
    context: str = ""

@app.post("/ai/meeting-briefing")
async def ai_meeting_briefing(payload: MeetingBriefingPayload):
    """Generate structured meeting briefing from all available sources."""
    
    # Step 1: Search all sources for meeting-related info
    search_payload = ContextSearchPayload(
        query=payload.meeting_title,
        lookback_days=30,
        sources={"calendar": True, "mail": True, "telegram": True, "whatsapp": True},
    )
    search_results = await ai_context_search(search_payload)
    
    # Also search by each participant
    for participant in pay    for participant in pay    for participant in pay    for partici        for participant in pay    for participant in pay    for participant in p"c    for participant in pay    for participant in pay    p": True},
        )
        p_results = await ai_context_search(p_payload)
                                                                rch_re                                                         ten                     []))
                   Buil                   Buil     t = pa                   Buil                   Buil     t = pa    h_r                   Buil                   Buil     t = pa              LLM for structured briefing
    system_prompt = """You are Jarvis A    system_prompt = """You are Jarvis A  
GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGe data (calendar, mail, messengers), create a structured briefing IN RUSSIAN:

1. СУТЬ ВСТРЕЧИ (what, who, why)
2. КЛЮЧЕВЫЕ ТЕМЫ (from all sources)
3. ИЗ ПЕРЕ�3. ИЗ ПЕРЕ�3. ИЗ ПЕРЕ�ts, 3. ИЗ ПЕРЕ�3. ИЗ ПЕРЕ�3. ИЗ ПЕРЕ�ts, 3. ИЗ ПЕРЕ�3. ИЗ ПЕРЕ�3. ИЗ ПЕРЕ�ts, 3. ИЗ ПЕРЕ�3. ИЗ ПЕРЕ�3. ИЗ ПЕРЕ�ts, 3. ИЗ ПЕРЕ�3. ИЗ ПЕРЕ�3. ИЗ ПЕРЕ�ts, 3. ИЗ ПЕРЕ�3. px3. ИЗ :
3. ИЗ ПЕРЕ�3. ИЗ ПЕРЕ�3. ИЗ ПЕРЕ�ts c3. ИЗ ПЕРЕ�3. ИЗ ПЕРЕ�3. ИЗ ПЕРЕ�ts c3. ИЗ ПЕРЕ�3. ИЗ ПЕРЕ�3. ИЗ ПЕРЕ�ts c3. ИЗ ПЕРЕ�3. ИЗ ПЕРЕ�3. ИЗ П                {"role": "system", "content": system_prompt},
                    {"role": "user", "content": context},
                ],
                "stream": False,
            })
            if r.status_code == 200            if r.status_code == 200            if r.status_code == 200         
                return {"briefing": text if text else "Failed to generate briefing."}
    except Exception as e:
        log.error(f"Meeting briefing LLM error: {e}")
    
    return {"briefing": f"LLM unavailable. Raw data:\n{json.dumps(search_results, ensure_ascii=False, default=str)[:3000]}"}


# ---------------------------------------------------------------------------
# AI DELEGATE TASK — Send task to user via messenger
# ---------------------------------------------------------------------------

class DelegateTaskPayload(BaseModel):
    task_title: str
    task_notes: str = ""
    assignee_handle: str
    platform: str = "telegram"

@app.post("/ai/delegate-task")
async def ai_delegate_task(payload: DelegateTaskPayload):
    """Delegate a task to another user via Telegram or WhatsApp."""
    message = f"📋 Вам назначена задача от Jarvis:\n\n*{payload.    message =
                                                                                                         тьте «принято» для подтверждения."
    
    if payload.platform == "telegram" and _telegram.is_authorized:
        try:
            # Send via Telegram
            sent = await _telegram.send_message(payload.assignee_handle, message)
            return {"status": "sent", "platform": "telegram", "details": str(sent)}
        except Exception as e:
            return {"status": "error", "error": str(e)}
    
    return {"status": "not_configured", "message": f"{payload.platform} not connected"}
