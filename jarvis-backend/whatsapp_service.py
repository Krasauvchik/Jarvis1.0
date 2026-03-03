"""
WhatsApp integration via Green API (REST-based WhatsApp Web bridge).

Green API (green-api.com) provides a REST API that connects through WhatsApp Web.
It's a paid service but the most stable/reliable way to access WhatsApp programmatically.

Alternative: self-host with Baileys/whatsmeow (see docs for setup).

Setup:
1. Register at https://green-api.com → get idInstance + apiTokenInstance
2. Scan QR code in Green API dashboard to link your WhatsApp account
3. POST /integrations/whatsapp/configure  {instance_id, api_token}
4. GET  /integrations/whatsapp/chats → list available chats
5. POST /integrations/whatsapp/chats/select {chat_ids: [...]}
6. GET  /integrations/whatsapp/digest → summarized from selected chats

If you prefer a free self-hosted solution, you can deploy a Baileys-based bridge:
  https://github.com/AliAryanTech/whatsapp-api-nodejs
and point Jarvis to its REST endpoints via the same interface.
"""

import json
import logging
from datetime import datetime, timezone
from collections import defaultdict
from pathlib import Path
from typing import Dict, List, Optional

log = logging.getLogger("jarvis.whatsapp")

CONFIG_PATH = Path(__file__).parent / "messenger_config.json"


def _load_config() -> dict:
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
    with open(CONFIG_PATH, "w") as f:
        json.dump(config, f, indent=2, ensure_ascii=False)


class WhatsAppService:
    """WhatsApp integration via Green API (or compatible REST bridge)."""

    BASE_URL = "https://api.green-api.com"

    def __init__(self):
        self._config = _load_config()

    # ------------------------------------------------------------------
    # Properties
    # ------------------------------------------------------------------

    @property
    def is_configured(self) -> bool:
        wa = self._config.get("whatsapp", {})
        return bool(wa.get("instance_id") and wa.get("api_token"))

    @property
    def selected_chat_ids(self) -> List[str]:
        return self._config.get("whatsapp", {}).get("selected_chats", [])

    @property
    def status(self) -> dict:
        wa = self._config.get("whatsapp", {})
        return {
            "configured": self.is_configured,
            "provider": wa.get("provider", "green-api"),
            "selected_chats_count": len(self.selected_chat_ids),
            "instance_id": wa.get("instance_id", ""),
        }

    # ------------------------------------------------------------------
    # Configuration
    # ------------------------------------------------------------------

    def configure(self, instance_id: str, api_token: str, base_url: Optional[str] = None):
        """Save WhatsApp API credentials.
        
        For Green API: instance_id + api_token from green-api.com dashboard.
        For self-hosted: instance_id + api_token + custom base_url.
        """
        self._config.setdefault("whatsapp", {})
        self._config["whatsapp"]["instance_id"] = instance_id
        self._config["whatsapp"]["api_token"] = api_token
        if base_url:
            self._config["whatsapp"]["base_url"] = base_url
        _save_config(self._config)
        log.info(f"WhatsApp configured: instance={instance_id}")

    # ------------------------------------------------------------------
    # API Helpers
    # ------------------------------------------------------------------

    def _api_url(self, method: str) -> str:
        """Build Green API URL for a given method."""
        wa = self._config.get("whatsapp", {})
        base = wa.get("base_url", self.BASE_URL)
        instance_id = wa.get("instance_id", "")
        api_token = wa.get("api_token", "")
        return f"{base}/waInstance{instance_id}/{method}/{api_token}"

    async def _api_get(self, method: str) -> Optional[dict]:
        """Make GET request to Green API."""
        import httpx
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                r = await client.get(self._api_url(method))
                if r.status_code == 200:
                    return r.json()
                log.warning(f"WhatsApp API {method}: HTTP {r.status_code}")
                return None
        except Exception as e:
            log.error(f"WhatsApp API {method} error: {e}")
            return None

    async def _api_post(self, method: str, body: dict) -> Optional[dict]:
        """Make POST request to Green API."""
        import httpx
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                r = await client.post(self._api_url(method), json=body)
                if r.status_code == 200:
                    return r.json()
                log.warning(f"WhatsApp API {method}: HTTP {r.status_code}")
                return None
        except Exception as e:
            log.error(f"WhatsApp API {method} error: {e}")
            return None

    # ------------------------------------------------------------------
    # Account Status
    # ------------------------------------------------------------------

    async def check_auth(self) -> dict:
        """Check if the WhatsApp instance is authorized (QR scanned)."""
        if not self.is_configured:
            return {"status": "not_configured"}

        result = await self._api_get("getStateInstance")
        if result:
            state = result.get("stateInstance", "unknown")
            # Green API states: notAuthorized, authorized, blocked, sleepMode
            return {
                "status": "authorized" if state == "authorized" else state,
                "raw": result,
            }
        return {"status": "error", "error": "Cannot reach Green API"}

    async def get_qr_code(self) -> Optional[str]:
        """Get QR code for scanning (if not yet authorized)."""
        if not self.is_configured:
            return None

        result = await self._api_get("qr")
        if result:
            return result.get("message")  # base64 QR image
        return None

    # ------------------------------------------------------------------
    # Chat Listing & Selection
    # ------------------------------------------------------------------

    async def list_chats(self) -> List[Dict]:
        """List available WhatsApp chats for user selection."""
        if not self.is_configured:
            return []

        result = await self._api_get("getChats")
        if not result or not isinstance(result, list):
            return []

        chats = []
        for chat in result:
            chat_id = chat.get("id", "")
            chat_name = chat.get("name", "") or chat.get("id", "Unknown")

            # Determine chat type from ID format
            if "@g.us" in chat_id:
                chat_type = "group"
            elif "@c.us" in chat_id:
                chat_type = "private"
            elif "@newsletter" in chat_id:
                chat_type = "channel"
            else:
                chat_type = "unknown"

            chats.append(
                {
                    "id": chat_id,
                    "title": chat_name,
                    "type": chat_type,
                    "selected": chat_id in self.selected_chat_ids,
                }
            )

        return chats

    def set_selected_chats(self, chat_ids: List[str]):
        """Save which chats the user wants to monitor."""
        self._config.setdefault("whatsapp", {})["selected_chats"] = chat_ids
        _save_config(self._config)
        log.info(f"WhatsApp: selected {len(chat_ids)} chats for monitoring")

    # ------------------------------------------------------------------
    # Message Reading
    # ------------------------------------------------------------------

    async def get_recent_messages(self, count_per_chat: int = 30) -> List[Dict]:
        """Read recent messages from selected chats only."""
        if not self.is_configured or not self.selected_chat_ids:
            return []

        all_messages = []
        for chat_id in self.selected_chat_ids:
            result = await self._api_post(
                "getChatHistory",
                {"chatId": chat_id, "count": count_per_chat},
            )
            if not result or not isinstance(result, list):
                continue

            # Get chat name
            chat_name = chat_id.split("@")[0]
            # Try to resolve from cached chats
            for msg in result:
                text = msg.get("textMessage") or msg.get("caption") or ""
                if not text:
                    continue

                sender = msg.get("senderName", "") or msg.get("senderId", "Unknown")
                timestamp = msg.get("timestamp", 0)
                date_str = ""
                if timestamp:
                    try:
                        date_str = datetime.fromtimestamp(
                            timestamp, tz=timezone.utc
                        ).isoformat()
                    except (ValueError, OSError):
                        pass

                all_messages.append(
                    {
                        "chat_id": chat_id,
                        "chat_title": msg.get("chatName", chat_name),
                        "sender": sender,
                        "text": text[:500],
                        "date": date_str,
                    }
                )

        return all_messages

    # ------------------------------------------------------------------
    # Digest Generation
    # ------------------------------------------------------------------

    async def generate_digest_text(self) -> str:
        """Build raw text digest from selected chats (for LLM summarization)."""
        messages = await self.get_recent_messages()
        if not messages:
            return "Нет новых сообщений в отслеживаемых чатах WhatsApp."

        by_chat = defaultdict(list)
        for m in messages:
            by_chat[m["chat_title"]].append(m)

        lines = []
        for chat_title, msgs in by_chat.items():
            lines.append(f"Чат «{chat_title}» ({len(msgs)} сообщений):")
            for m in msgs[-15:]:
                date_part = f"[{m['date'][:16]}] " if m["date"] else ""
                lines.append(f"  {date_part}{m['sender']}: {m['text'][:300]}")
            lines.append("")

        return "\n".join(lines)

    # ------------------------------------------------------------------
    # Disconnect
    # ------------------------------------------------------------------

    async def disconnect(self):
        """Logout from Green API instance."""
        if self.is_configured:
            await self._api_get("logout")

        self._config.setdefault("whatsapp", {})["selected_chats"] = []
        self._config["whatsapp"]["instance_id"] = None
        self._config["whatsapp"]["api_token"] = None
        _save_config(self._config)
        log.info("WhatsApp: disconnected")
