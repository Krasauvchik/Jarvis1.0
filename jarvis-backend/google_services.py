"""Google Calendar & Gmail API wrappers."""
import base64
import logging
from datetime import datetime, timedelta
from email.mime.text import MIMEText
from typing import Optional, List, Dict

from googleapiclient.discovery import build

log = logging.getLogger("jarvis.google")


class GoogleCalendarService:
    """Обёртка над Google Calendar API v3."""

    def __init__(self, credentials):
        self.service = build("calendar", "v3", credentials=credentials)

    def list_events(
        self,
        days_ahead: int = 7,
        max_results: int = 50,
        calendar_id: str = "primary",
    ) -> List[dict]:
        now = datetime.utcnow()
        time_min = now.isoformat() + "Z"
        time_max = (now + timedelta(days=days_ahead)).isoformat() + "Z"

        result = (
            self.service.events()
            .list(
                calendarId=calendar_id,
                timeMin=time_min,
                timeMax=time_max,
                maxResults=max_results,
                singleEvents=True,
                orderBy="startTime",
            )
            .execute()
        )

        events = []
        for item in result.get("items", []):
            start = item.get("start", {})
            end = item.get("end", {})
            events.append({
                "id": item.get("id"),
                "title": item.get("summary", "(без названия)"),
                "notes": item.get("description"),
                "startDate": start.get("dateTime") or start.get("date"),
                "endDate": end.get("dateTime") or end.get("date"),
                "location": item.get("location"),
                "isAllDay": "date" in start and "dateTime" not in start,
                "htmlLink": item.get("htmlLink"),
            })
        return events

    def create_event(
        self,
        summary: str,
        start_iso: str,
        end_iso: str,
        description: str = "",
        timezone: str = "Europe/Moscow",
        calendar_id: str = "primary",
    ) -> dict:
        # If end is empty, default to 1 hour after start
        if not end_iso and start_iso:
            try:
                start_dt = datetime.fromisoformat(start_iso.replace("Z", "+00:00"))
                end_iso = (start_dt + timedelta(hours=1)).isoformat()
            except Exception:
                end_iso = start_iso

        body = {
            "summary": summary,
            "description": description,
            "start": {"dateTime": start_iso, "timeZone": timezone},
            "end": {"dateTime": end_iso, "timeZone": timezone},
        }
        event = self.service.events().insert(calendarId=calendar_id, body=body).execute()
        log.info(f"Created event: {event.get('id')} — {summary}")
        return {
            "id": event.get("id"),
            "title": event.get("summary"),
            "htmlLink": event.get("htmlLink"),
            "startDate": start_iso,
            "endDate": end_iso,
        }

    def update_event(
        self,
        event_id: str,
        updates: dict,
        calendar_id: str = "primary",
    ) -> dict:
        existing = self.service.events().get(calendarId=calendar_id, eventId=event_id).execute()

        if "summary" in updates:
            existing["summary"] = updates["summary"]
        if "description" in updates:
            existing["description"] = updates["description"]
        if "start" in updates:
            tz = updates.get("timeZone", "Europe/Moscow")
            existing["start"] = {"dateTime": updates["start"], "timeZone": tz}
        if "end" in updates:
            tz = updates.get("timeZone", "Europe/Moscow")
            existing["end"] = {"dateTime": updates["end"], "timeZone": tz}

        updated = self.service.events().update(
            calendarId=calendar_id, eventId=event_id, body=existing
        ).execute()
        return {"id": updated.get("id"), "title": updated.get("summary")}

    def delete_event(self, event_id: str, calendar_id: str = "primary"):
        self.service.events().delete(calendarId=calendar_id, eventId=event_id).execute()
        log.info(f"Deleted event: {event_id}")


class GmailService:
    """Обёртка над Gmail API v1."""

    def __init__(self, credentials):
        self.service = build("gmail", "v1", credentials=credentials)

    def list_messages(
        self,
        max_results: int = 15,
        query: str = "",
    ) -> List[dict]:
        q = query or "in:inbox"
        result = self.service.users().messages().list(
            userId="me", q=q, maxResults=max_results
        ).execute()

        messages = []
        for msg_stub in result.get("messages", []):
            try:
                msg = self.service.users().messages().get(
                    userId="me", id=msg_stub["id"], format="metadata",
                    metadataHeaders=["Subject", "From", "Date"],
                ).execute()
                headers = {h["name"]: h["value"] for h in msg.get("payload", {}).get("headers", [])}
                messages.append({
                    "id": msg["id"],
                    "threadId": msg.get("threadId"),
                    "subject": headers.get("Subject", "(без темы)"),
                    "from": headers.get("From", ""),
                    "date": headers.get("Date", ""),
                    "snippet": msg.get("snippet", ""),
                    "isUnread": "UNREAD" in msg.get("labelIds", []),
                })
            except Exception as e:
                log.warning(f"Failed to fetch message {msg_stub['id']}: {e}")
        return messages

    def get_message(self, message_id: str) -> dict:
        msg = self.service.users().messages().get(
            userId="me", id=message_id, format="full"
        ).execute()
        headers = {h["name"]: h["value"] for h in msg.get("payload", {}).get("headers", [])}

        # Extract body
        body_text = ""
        payload = msg.get("payload", {})
        if "parts" in payload:
            for part in payload["parts"]:
                if part.get("mimeType") == "text/plain":
                    data = part.get("body", {}).get("data", "")
                    if data:
                        body_text = base64.urlsafe_b64decode(data).decode("utf-8", errors="replace")
                    break
        elif payload.get("body", {}).get("data"):
            body_text = base64.urlsafe_b64decode(payload["body"]["data"]).decode("utf-8", errors="replace")

        return {
            "id": msg["id"],
            "threadId": msg.get("threadId"),
            "subject": headers.get("Subject", ""),
            "from": headers.get("From", ""),
            "to": headers.get("To", ""),
            "date": headers.get("Date", ""),
            "body": body_text,
            "snippet": msg.get("snippet", ""),
            "isUnread": "UNREAD" in msg.get("labelIds", []),
        }

    def send_message(self, to: str, subject: str, body: str) -> dict:
        message = MIMEText(body)
        message["to"] = to
        message["subject"] = subject
        raw = base64.urlsafe_b64encode(message.as_bytes()).decode("utf-8")
        result = self.service.users().messages().send(
            userId="me", body={"raw": raw}
        ).execute()
        log.info(f"Sent email to {to}: {subject}")
        return {"id": result.get("id"), "threadId": result.get("threadId")}

    def reply_to_message(self, message_id: str, body: str) -> dict:
        original = self.get_message(message_id)
        thread_id = original.get("threadId")
        subject = original.get("subject", "")
        if not subject.startswith("Re:"):
            subject = f"Re: {subject}"
        from_addr = original.get("from", "")

        message = MIMEText(body)
        message["to"] = from_addr
        message["subject"] = subject
        message["In-Reply-To"] = message_id
        message["References"] = message_id

        raw = base64.urlsafe_b64encode(message.as_bytes()).decode("utf-8")
        result = self.service.users().messages().send(
            userId="me", body={"raw": raw, "threadId": thread_id}
        ).execute()
        log.info(f"Replied to {message_id}")
        return {"id": result.get("id"), "threadId": result.get("threadId")}

    def archive_message(self, message_id: str):
        self.service.users().messages().modify(
            userId="me", id=message_id,
            body={"removeLabelIds": ["INBOX"]},
        ).execute()
        log.info(f"Archived message: {message_id}")
