# Jarvis Backend

API для приложения Jarvis Planner (календарь, анализ питания, LLM-советы).

## Endpoints

| Метод | Путь | Описание |
|-------|------|----------|
| GET | /health | Проверка работоспособности |
| GET | /auth/status | Проверка авторизации Google |
| GET | /auth/google | Редирект на авторизацию Google |
| GET | /auth/callback | Callback после авторизации Google |
| GET | /calendar/events | События календаря (Google или mock) |
| GET | /mail/messages | Последние письма Gmail (?max_results=10) |
| POST | /analyze-meal | Анализ фото блюда → { title, calories } |
| POST | /llm/plan | Советы по задачам → { advice } |

## Google Calendar и Gmail

### 1. Скачать credentials

В [Google Cloud Console](https://console.cloud.google.com) → Credentials → OAuth client "Jarvis" → **Download JSON**.  
Сохранить как `credentials.json` в папку `jarvis-backend`.

### 2. Переменная окружения (если нужен другой BASE_URL)

```bash
export BASE_URL=http://jarvis-app.mooo.com:8000
```

### 3. Авторизация

Открыть в браузере: `http://jarvis-app.mooo.com:8000/auth/google`  
После входа в Google сохранится `token.json`. Домен `jarvis-app.mooo.com` должен указывать на IP сервера.

## Сервер

Backend развёрнут на `158.160.48.202:8000`.  
Домен: `jarvis-app.mooo.com` (должен указывать на этот IP).

### Перезапуск (если упал)

```bash
ssh -i ~/.ssh/bilal_key bilal@158.160.48.202
cd ~/jarvis-backend && source venv/bin/activate
pip install -r requirements.txt
nohup uvicorn main:app --host 0.0.0.0 --port 8000 > server.log 2>&1 &
```

### Запуск как systemd-сервис (требуется sudo)

```bash
# На сервере:
sudo cp ~/jarvis-backend/jarvis-backend.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable jarvis-backend
sudo systemctl start jarvis-backend
sudo systemctl status jarvis-backend
```
