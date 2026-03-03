"""
Telegram integration via Telethon (MTProto user client).

Allows Jarvis to read messages from user-permitted chats and generate digests.
The user authenticates with their own Telegram account (phone + code + optional 2FA).
They then select SPECIFIC chats to monitor — Jarvis only reads those.

Setup:
1. Get api_id + api_hash from https://my.telegram.org/apps
2. POST /integrations/telegram/configure  {api_id, api_hash, phone}
3. POST /integrations/telegram/auth/start → sends code to phone
4. POST /integrations/telegram/auth/complete {code, phone_code_hash}
5. GET  /integrations/telegram/chats → list available chats
6. POST /integrations/telegram/chats/select {chat_ids: [...]}
7. GET  /integrations/telegram/digest → summarized from selected chats
"""

import json
import logging
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Dict, List, Optional

log = logging.getLogger("jarvis.telegram")

CONFIG_PATH = Path(__file__).parent / "messenger_config.json"
SESSION_NAME = str(Path(__file__).parent / "telegram_session")


def _load_config() -> dict:
    """Load messenger config from disk."""
    if CONFIG_PATH.exists():
        try:
            with open(CONFIG_PATH) as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError):
            pass
    return {
        "telegram": {
            "api_id": None,
            "api_hash": None,
            "phone": None,
            "selected_chats": [],
        },
        "whatsapp": {
            "provider": "green-api",
            "instance_id": None,
            "api_token": None,
            "selected_chats": [],
        },
    }


def _save_config(config: dict):
    """Persist messenger config to disk."""
    with open(CONFIG_PATH, "w") as f:
        json.dump(config, f, indent=2, ensure_ascii=False)


class TelegramService:
    """Manages Telegram user client via Telethon for reading permitted chats."""

    def __init__(self):
        self._client = None
        self._config = _load_config()

    # ------------------------------------------------------------------
    # Properties
    # ------------------------------------------------------------------

    @property
    def is_configured(self) -> bool:
        tg = self._config.get("telegram", {})
        return bool(tg.get("api_id") and tg.get("api_hash") and tg.get("phone"))

    @property
    def selected_chat_ids(self) -> List[int]:
        return self._config.get("telegram", {}).get("selected_chats", [])

    @property
    def status(self) -> dict:
        tg = self._config.get("telegram", {})
        session_file = Path(SESSION_NAME + ".session")
        return {
            "configured": self.is_configured,
            "has_session": session_file.exists(),
            "selected_chats_count": len(self.selected_chat_ids),
            "phone": tg.get("phone", ""),
        }

    # ------------------------------------------------------------------
    # Configuration
    # ------------------------------------------------------------------

    def configure(self, api_id: int, api_hash: str, phone: str):
        """Save Telegram API credentials."""
        self._config.setdefault("telegram", {})
        self._config["telegram"]["api_id"] = api_id
        self._config["telegram"]["api_hash"] = api_hash
        self._config["telegram"]["phone"] = phone
        _save_config(self._config)
        log.info(f"Telegram configured for phone: {phone}")

    # ------------------------------------------------------------------
    # Authentication
    # ------------------------------------------------------------------

    async def start_auth(self) -> dict:
        """Start authentication — sends code to the user's phone."""
        if not self.is_configured:
            return {"status": "error", "error": "Not configured. Call /configure first."}

        try:
            from telethon import TelegramClient

            tg = self._config["telegram"]
            self._client = TelegramClient(
                SESSION_NAME, int(tg["api_id"]), tg["api_hash"]
            )
            await self._client.connect()

            if await self._client.is_user_authorized():
                me = await self._client.get_me()
                return {
                    "status": "already_authorized",
                    "user": me.first_name if me else "User",
                }

            result = await self._client.send_code_request(tg["phone"])
            return {"status": "code_sent", "phone_code_hash": result.phone_code_hash}

        except Exception as e:
            log.error(f"Telegram auth start error: {e}")
            return {"status": "error", "error": str(e)}

    async def complete_auth(
        self, code: str, phone_code_hash: str, password: Optional[str] = None
    ) -> dict:
        """Complete authentication with the code received via SMS/Telegram."""
        try:
            from telethon import TelegramClient
            from telethon.errors import SessionPasswordNeededError

            if not self._client:
                tg = self._config["telegram"]
                self._client = TelegramClient(
                    SESSION_NAME, int(tg["api_id"]), tg["api_hash"]
                )
                await self._client.connect()

            tg = self._config["telegram"]
            try:
                await self._client.sign_in(
                    tg["phone"], code, phone_code_hash=phone_code_hash
                )
            except SessionPasswordNeededError:
                if password:
                    await self._client.sign_in(password=password)
                else:
                    return {"status": "need_2fa"}

            me = await self._client.get_me()
            return {
                "status": "authorized",
                "user": me.first_name if me else "User",
            }

        except Exception as e:
            log.error(f"Telegram auth complete error: {e}")
            return {"status": "error", "error": str(e)}

    # ------------------------------------------------------------------
    # Client Management
    # ------------------------------------------------------------------

    async def _get_client(self):
        """Get an authenticated Telethon client (reconnects if needed)."""
        if self._client and self._client.is_connected():
            if await self._client.is_user_authorized():
                return self._client

        from telethon import TelegramClient

        tg = self._config.get("telegram", {})
        if not tg.get("api_id"):
            return None

        self._client = TelegramClient(
            SESSION_NAME, int(tg["api_id"]), tg["api_hash"]
        )
        await self._client.connect()

        if not await self._client.is_user_authorized():
            return None

        return self._client

    # ------------------------------------------------------------------
    # Chat Listing & Selection
    # ------------------------------------------------------------------

    async def list_chats(self, limit: int = 50) -> List[Dict]:
        """List user's dialogs so they can select which to monitor."""
        client = await self._get_client()
        if not client:
            return []

        from telethon.tl.types import Channel, Chat, User

        dialogs = await client.get_dialogs(limit=limit)
        chats = []
        for d in dialogs:
            entity = d.entity
            chat_type = "unknown"
            if isinstance(entity, User):
                chat_type = "private"
            elif isinstance(entity, Chat):
                chat_type = "group"
            elif isinstance(entity, Channel):
                chat_type = "channel" if entity.broadcast else "supergroup"

            chats.append(
                {
                    "id": d.id,
                    "title": d.title or d.name or "Unknown",
                    "type": chat_type,
                    "unread_count": d.unread_count,
                    "selected": d.id in self.selected_chat_ids,
                }
            )

        return chats

    def set_selected_chats(self, chat_ids: List[int]):
        """Save which chat IDs the user wants to monitor."""
        self._config.setdefault("telegram", {})["selected_chats"] = chat_ids
        _save_config(self._config)
        log.info(f"Telegram: selected {len(chat_ids)} chats for monitoring")

    # ------------------------------------------------------------------
    # Message Reading
    # ------------------------------------------------------------------

    async def get_recent_messages(
        self, hours: int = 24, per_chat_limit: int = 50
    ) -> List[Dict]:
        """Read recent messages from selected chats only."""
        client = await self._get_client()
        if not client:
            return []

        cutoff = datetime.now(timezone.utc) - timedelta(hours=hours)
        all_messages = []

        # Pre-fetch chat entities for titles
        chat_titles: Dict[int, str] = {}
        for chat_id in self.selected_chat_ids:
            try:
                entity = await client.get_entity(chat_id)
                chat_titles[chat_id] = getattr(entity, "title", None) or getattr(
                    entity, "first_name", str(chat_id)
                )
            except Exception:
                chat_titles[chat_id] = str(chat_id)

        for chat_id in self.selected_chat_ids:
            try:
                messages = await client.get_messages(chat_id, limit=per_chat_limit)
                for msg in messages:
                    if msg.date and msg.date < cutoff:
                        break
                    if not msg.text:
                        continue

                    sender_name = "Unknown"
                    if msg.sender:
                        sender_name = (
                            getattr(msg.sender, "first_name", "")
                            or getattr(msg.sender, "title", "")
                            or "Unknown"
                        )

                    all_messages.append(
                        {
                            "chat_id": chat_id,
                            "chat_title": chat_titles.get(chat_id, str(chat_id)),
                            "sender": sender_name,
                            "text": msg.text[:500],
                            "date": msg.date.isoformat() if msg.date else "",
                        }
                    )
            except Exception as e:
                log.warning(f"Error reading Telegram chat {chat_id}: {e}")

        return all_messages

    # ------------------------------------------------------------------
    # Digest Generation
    # ------------------------------------------------------------------

    async def generate_digest_text(self, hours: int = 24) -> str:
        """Build raw text digest from selected chats (for LLM summarization)."""
        messages = await self.get_recent_messages(hours=hours)
        if not messages:
            return "Нет новых сообщений в отслеживаемых чатах Telegram."

        by_chat = defaultdict(list)
        for m in messages:
            by_chat[m["chat_title"]].append(m)

        lines = []
        for chat_title, msgs in by_chat.items():
            lines.append(f"Чат «{chat_title}» ({len(msgs)} сообщений за {hours}ч):")
            # Show last 15 messages per chat for context
            for m in msgs[-15:]:
                lines.append(f"  [{m['date'][:16]}] {m['sender']}: {m['text'][:300]}")
            lines.append("")

        return "\n".join(lines)

    # ------------------------------------------------------------------
    # Disconnect
    # ------------------------------------------------------------------

    async def disconnect(self):
        """Logout, remove session, clear selected chats."""
        if self._client:
            try:
                await self._client.log_out()
            except Exception:
                pass
            self._client = None

        session_file = Path(SESSION_NAME + ".session")
        if session_file.exists():
            session_file.unlink()

        self._config.setdefault("telegram", {})["selected_chats"] = []
        _save_config(self._config)
        log.info("Telegram: disconnected and session removed")
