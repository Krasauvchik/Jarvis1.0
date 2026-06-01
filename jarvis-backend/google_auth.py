"""Google OAuth и API (Calendar, Gmail)."""
import os
import secrets
import stat
from pathlib import Path
from typing import Optional

from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import Flow
from google.auth.transport.requests import Request

# Пути
CREDENTIALS_PATH = Path(__file__).parent / "credentials.json"
TOKEN_PATH = Path(__file__).parent / "token.json"

# Скапы доступа
SCOPES = [
    "https://www.googleapis.com/auth/calendar.readonly",
    "https://www.googleapis.com/auth/calendar.events",
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/gmail.modify",
]


def _write_token(creds) -> None:
    """Persist OAuth credentials to disk with owner-only (0600) permissions.

    The token file holds long-lived refresh tokens and client secrets; it must never
    be world- or group-readable. We create it with a restrictive umask and tighten
    the mode afterwards in case the file already existed.
    """
    data = creds.to_json()
    # Open with O_CREAT honoring an explicit 0600 mode for newly created files.
    fd = os.open(TOKEN_PATH, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    try:
        with os.fdopen(fd, "w") as f:
            f.write(data)
    finally:
        # Enforce 0600 even if the file pre-existed with looser permissions.
        try:
            os.chmod(TOKEN_PATH, stat.S_IRUSR | stat.S_IWUSR)
        except OSError:
            pass


def get_auth_url(redirect_uri: str) -> str:
    """Создаёт URL для авторизации в Google. code_verifier передаётся через state."""
    code_verifier = secrets.token_urlsafe(64)
    flow = Flow.from_client_secrets_file(
        str(CREDENTIALS_PATH),
        scopes=SCOPES,
        redirect_uri=redirect_uri,
        code_verifier=code_verifier,
    )
    auth_url, _ = flow.authorization_url(
        access_type="offline",
        prompt="consent",
        include_granted_scopes="true",
        state=code_verifier,
    )
    return auth_url


def exchange_code_for_token(code: str, redirect_uri: str, code_verifier: str) -> bool:
    """Обменивает код авторизации на токены и сохраняет их."""
    flow = Flow.from_client_secrets_file(
        str(CREDENTIALS_PATH),
        scopes=SCOPES,
        redirect_uri=redirect_uri,
        code_verifier=code_verifier,
    )
    flow.fetch_token(code=code)
    credentials = flow.credentials
    _write_token(credentials)
    return True


def get_credentials() -> Optional[Credentials]:
    """Возвращает сохранённые credentials или None, если не авторизован."""
    if not TOKEN_PATH.exists():
        return None

    creds = Credentials.from_authorized_user_file(str(TOKEN_PATH), SCOPES)
    if creds.expired and creds.refresh_token:
        try:
            creds.refresh(Request())
            _write_token(creds)
        except Exception:
            return None
    if not creds.valid:
        return None
    return creds


def is_authorized() -> bool:
    """Проверяет, есть ли сохранённая авторизация."""
    return get_credentials() is not None
