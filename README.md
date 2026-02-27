# Jarvis

Планировщик с интеграцией Google Calendar, Gmail, анализом питания и AI-советами.

## Состав

- **jarvis-backend** — FastAPI API (календарь, почта, OAuth Google, анализ блюд, LLM-советы)
- **Jarvis** — iOS/macOS приложение (SwiftUI)

## Backend

```bash
cd jarvis-backend
pip install -r requirements.txt
# Положить credentials.json (Google OAuth) в папку jarvis-backend
uvicorn main:app --host 0.0.0.0 --port 8000
```

Документация: [jarvis-backend/README.md](jarvis-backend/README.md)

## Приложение

Открыть `Jarvis/Jarvis.xcodeproj` в Xcode, собрать и запустить.

Вкладки: План, Календарь, Почта, Аналитика, Здоровье.  
Для Календаря и Почты нужна авторизация Google (кнопка «Войти через Google» в приложении).

## Деплой

Backend развёрнут на `http://jarvis-app.mooo.com:8000`.  
Домен `jarvis-app.mooo.com` указывает на сервер с backend.
