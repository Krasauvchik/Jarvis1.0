# Jarvis — Статус готовности

> Единый источник правды по тому, что готово и что осталось до полноценного использования.
> Обновляется по мере прогресса. Последнее обновление: 2026-06-02.

Платформы: iOS 17+ / iPadOS 17+ / macOS 14+ / watchOS 10+.
Сборка macOS: **BUILD SUCCEEDED**. Unit-тесты (`JarvisTests`): **проходят**.

---

## 1. Что уже работает на устройстве (без бэкенда)
- Задачи: входящие, сегодня, запланированные, проекты, теги, повторения.
- Локальный календарь через EventKit (события системного «Календаря»).
- Wellness (еда/сон/активность), аналитика.
- Прямой Gemini (chat / планирование / брифинги встреч) — **после ввода своего API-ключа**.
- Синхронизация между устройствами через iCloud (нужен вход в iCloud).
- Секреты (ключи) хранятся в Keychain; строгий ATS (только HTTPS).

## 2. Матрица зависимостей фич

| Фича | Нужен бэкенд | Серверные креды | iCloud |
|------|:---:|:---:|:---:|
| Задачи / локальный календарь / wellness | — | — | для синка |
| Gemini напрямую (chat, брифинги) | — | ключ Gemini (в приложении) | — |
| Google Calendar / Gmail | ✅ | OAuth `credentials.json` | — |
| Telegram, делегирование, контекст-поиск | ✅ | API id/hash + телефон | — |
| Анализ фото еды, дайджест | ✅ | `GEMINI_API_KEY` на сервере | — |

## 3. Чек-лист до полноценного использования

### Клиент (сделано в этой итерации)
- [x] Секреты в Keychain + миграция; убран встроенный Gemini-ключ.
- [x] Строгий ATS (HTTPS-only); релизный URL = `https://jarvis-app.mooo.com`.
- [x] Онбординг: шаг ввода Gemini-ключа + запрос разрешения на уведомления.
- [x] YandexGPT помечен «Скоро», выбор заблокирован.
- [x] Bundle id → `com.jarvis.planner` (согласован с App Group/iCloud).
- [x] Иконки приложения: плейсхолдер-набор сгенерирован (`Scripts/generate_app_icons.py`).
- [x] Виджет: приложение шлёт `WidgetCenter.reloadAllTimelines()`, создан `JarvisWidgetExtension.entitlements` (App Group).
- [x] Siri-intent «Show Today» открывает раздел «Сегодня».

### Клиент — осталось (нужны твои действия)
- [ ] **Team ID**: в Xcode → target Jarvis → Signing & Capabilities → выбрать свою команду (Apple Developer). Без него на устройство не подпишется. (В проекте `DEVELOPMENT_TEAM` пуст намеренно.)
- [ ] **Виджет — добавить target в Xcode** (ручная правка проекта рискованна, делается в GUI за ~2 мин):
  1. File → New → Target → **Widget Extension**, имя `JarvisWidgetExtension`, снять «Include Configuration App Intent».
  2. Удалить автосозданные файлы-болванки, оставить существующий `JarvisWidgetExtension/JarvisWidget.swift`.
  3. В Signing & Capabilities виджета добавить **App Group** `group.com.jarvis.planner` (entitlements уже лежит в папке).
  4. Bundle id виджета: `com.jarvis.planner.widget`.
  5. Собрать схему виджета.
- [ ] (Опционально) Заменить плейсхолдер-иконку: положить свой 1024×1024 или поправить цвета в `Scripts/generate_app_icons.py` и перезапустить.
- [ ] (Опционально) Локализовать строки виджета (после создания target — через его собственный strings-каталог).

### Сервер (твои действия, скрипты выданы в чате)
- [ ] Новый **Gemini-ключ** в `.env` (`GEMINI_API_KEY`), `/health` → `"gemini": true`.
- [ ] `JARVIS_ENV=production`, `JARVIS_API_KEY=<секрет>` (в systemd), при нужде `JARVIS_ALLOWED_ORIGINS`.
- [ ] **TLS**: Caddy на `jarvis-app.mooo.com` (Let's Encrypt), uvicorn на `127.0.0.1:8000`.
- [ ] **OAuth redirect**: в Google Cloud Console и `credentials.json` — `https://jarvis-app.mooo.com/auth/callback`; на сервере `GOOGLE_REDIRECT_URI` тот же.
- [ ] Проверка: `curl https://jarvis-app.mooo.com/health` (валидный серт).
- [ ] 🔴 Отозвать засвеченные в чате ключи (Gemini + SSH), выпустить новые, в чат не присылать.

## 4. Переменные окружения бэкенда
`GEMINI_API_KEY`, `JARVIS_ENV` (development|production), `JARVIS_API_KEY`,
`JARVIS_ALLOWED_ORIGINS` (CSV), `JARVIS_ENABLE_DOCS` (0/1),
`GOOGLE_REDIRECT_URI`. Креды: `credentials.json` (Google OAuth), Telegram api_id/api_hash.

## 5. Известные подводные камни
- **iCloud-конфликтные копии**: папка `Desktop/Cursor` синкается через iCloud и плодит дубликаты `«Foo 2.swift»`, которые Xcode 16 (synchronized groups) компилирует → `invalid redeclaration` и падение сборки. Лечится удалением:
  ```
  find Jarvis jarvis-backend docs -regex '.* [0-9]\.\(swift\|py\|plist\|json\|md\)' | grep -v '/.git/' | while read -r f; do rm -f "$f"; done
  ```
  Радикально — вынести репозиторий из iCloud-папки.
- Прод требует валидного TLS-сертификата (строгий ATS): голый IP/self-signed не подойдёт.

## 6. Команды проверки
```
# Сборка (без подписи)
xcodebuild build -scheme Jarvis -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO
# Тесты
xcodebuild test -scheme Jarvis -destination 'platform=macOS' -only-testing:JarvisTests CODE_SIGNING_ALLOWED=NO
# Бэкенд
curl https://jarvis-app.mooo.com/health
```
