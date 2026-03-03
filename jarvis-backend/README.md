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

## HTTPS (TLS)

По умолчанию backend запускается с самоподписанным TLS-сертификатом.

### Генерация сертификата (автоматически при первом запуске)

```bash
bash generate_certs.sh
```

### Запуск с HTTPS (по умолчанию)

```bash
bash start.sh
```

### Запуск без TLS (HTTP) — только для отладки

```bash
JARVIS_NO_TLS=1 bash start.sh
```

### Доверие сертификату на macOS (убирает предупреждения)

```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain certs/server.crt
```

### Продакшн — Let's Encrypt

Для продакшна замените самоподписанные сертификаты на Let's Encrypt:

```bash
# Через certbot:
sudo certbot certonly --standalone -d your-domain.com
# Затем укажите пути:
uvicorn main:app --host 0.0.0.0 --port 443 \
    --ssl-keyfile /etc/letsencrypt/live/your-domain.com/privkey.pem \
    --ssl-certfile /etc/letsencrypt/live/your-domain.com/fullchain.pem
```
