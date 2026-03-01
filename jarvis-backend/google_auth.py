"""Google OAuth и API (Calendar, Gmail)."""
import secrets
from pathlib import Path

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
    with open(TOKEN_PATH, "w") as f:
        f.write(credentials.to_json())
    return True


def get_credentials() -> Credentials | None:
    """Возвращает сохранённые credentials или None, если не авторизован."""
    if not TOKEN_PATH.exists():
        return None

    creds = Credentials.from_authorized_user_file(str(TOKEN_PATH), SCOPES)
    if creds.expired and creds.refresh_token:
        creds.refresh(Request())
        with open(TOKEN_PATH, "w") as f:
            f.write(creds.to_json())
    return creds


def is_authorized() -> bool:
    """Проверяет, есть ли сохранённая авторизация."""
    return get_credentials() is not None
