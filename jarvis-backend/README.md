# Jarvis Backend

API для приложения Jarvis Planner (календарь, анализ питания, LLM-советы).

## Endpoints

| Метод | Путь | Описание |
|-------|------|----------|
| GET | /health | Проверка работоспособности |
| GET | /calendar/events | События календаря (пока mock) |
| POST | /analyze-meal | Анализ фото блюда → { title, calories } |
| POST | /llm/plan | Советы по задачам → { advice } |

## Сервер

Backend развёрнут на `158.160.48.202:8000`.

### Перезапуск (если упал)

```bash
ssh -i ~/.ssh/bilal_key bilal@158.160.48.202
cd ~/jarvis-backend && source venv/bin/activate
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

## Будущие интеграции

- **Google Calendar**: OAuth + Google Calendar API
- **Nutrition AI**: Gemini Vision / OpenAI для распознавания блюд
- **LLM**: OpenAI / Anthropic для умных советов
