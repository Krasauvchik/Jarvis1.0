# Jarvis Backend

API для приложения Jarvis Planner (календарь, анализ питания, LLM-советы).

## Endpoints (основные)

| Метод | Путь | Описание |
|-------|------|----------|
| GET | /health | Проверка работоспособности + статус Ollama |
| GET | /calendar/events | События Google Calendar |
| POST | /calendar/events | Создание события в календаре |
| GET | /mail/messages | Список писем Gmail |
| POST | /mail/send | Отправка письма |
| POST | /llm/plan | LLM‑советы по задачам (Cloud → Ollama → heuristic) |
| POST | /llm/chat | Прокси‑чат (Cloud → Ollama) |
| POST | /ai/command | Унифицированные голосовые команды (AIAction JSON) |
| POST | /ai/digest | AI‑дайджест (календарь+почта+мессенджеры) |
| POST | /ai/context-search | Кросс‑поиск по календарю/почте/мессенджерам |
| POST | /ai/meeting-briefing | Брифинг по встрече |
| POST | /ai/delegate-task | Делегирование задачи через мессенджер (preview) |

## Сервер

Публичный адрес: `https://jarvis-app.mooo.com` (валидный TLS через Caddy на :443,
проксирует на внутренний uvicorn `127.0.0.1:8000`). Запускается через systemd-сервис
`jarvis-backend` (см. `jarvis-backend.service`). SSH — по IP сервера.

### Перезапуск (если упал)

```bash
ssh bilal@158.160.48.202        # используйте свой текущий SSH-ключ
sudo systemctl restart jarvis-backend
sudo systemctl status jarvis-backend
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

## LLM‑слой

Backend поддерживает 3 уровня работы с AI:

- **Cloud LLM (Cloud GPT / совместимые)** — используется, если заданы переменные окружения:
    - `JARVIS_CLOUD_LLM_API_KEY`
    - `JARVIS_CLOUD_LLM_MODEL` (по умолчанию `gpt-4.1-mini`)
    - `JARVIS_CLOUD_LLM_BASE_URL` (по умолчанию `https://api.openai.com/v1`)
    - Задействуется в `/llm/plan`, `/llm/chat`, `/ai/command`, `/ai/digest`, Telegram/WhatsApp‑дайджестах, `/ai/meeting-briefing`.
- **Ollama (локальная LLM)** — используется как fallback и локальный режим:
    - HTTP API `http://localhost:11434/api/generate` и `/api/chat`.
    - Модель по умолчанию `llama3.2`.
- **Эвристики** — простые правила, если LLM недоступны.

Таким образом, цепочка для большинства эндпоинтов:

> Cloud LLM → Ollama → heuristic

и при этом конфиденциальные данные остаются на вашем сервере.

## Будущие интеграции

- **Nutrition AI**: Gemini Vision / OpenAI для распознавания блюд

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
