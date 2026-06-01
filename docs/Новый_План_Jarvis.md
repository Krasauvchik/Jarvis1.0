# Jarvis Planner — Актуальный план (март 2026)

## Что готово (100%)

| Модуль | Детали |
|--------|--------|
| Задачи (CRUD) | Создание, редактирование, удаление, повтор, приоритеты, категории, теги |
| Разделы задач | Inbox, Сегодня, Запланированные, Будущие планы, Выполненные |
| Drag-to-reschedule | 15-мин привязка, визуальный таймлайн |
| SwiftData + iCloud | Автоматическая синхронизация, миграция с UserDefaults |
| Wellness | Питание, сон, активность, вода — полный трекинг + история + цели |
| Уведомления | За 15 мин, отмена при удалении/переносе |
| Голосовой ввод | SFSpeechRecognizer, команды (создать, удалить, перенести) |
| AI Manager | Gemini + YandexGPT + Heuristic + fallback-цепочка |
| AI Life Coach | Персональные советы по здоровью |
| Meeting Briefing | Подготовка к встречам из календаря |
| LLM Digest | Дайджест дня из задач, календаря, почты |
| Локализация | RU + EN, String Catalog, 100+ ключей |
| Экспорт/Импорт | JSON сериализация задач |
| App Lock | PIN / Face ID |
| Deep Links | jarvis:// навигация |
| Siri Shortcuts | App Intents |
| Виджет | Home Screen, снимок задач |
| Onboarding | 7-шаговый мастер |
| UI iPhone | 6 вкладок (Today/Inbox/Mail/AI/Analytics/Settings) |
| UI iPad/Mac | 3-column (sidebar + список + таймлайн) |
| Темы | Светлая/тёмная, 7+ цветов задач |
| EventKit | Чтение локального календаря iPhone |
| CalendarSync | Объединение EventKit + задачи |
| Аналитика | TaskStatistics по дням |
| Режимы | Work / Personal переключение |

## Что частично реализовано

| Модуль | Готово | Не готово |
|--------|--------|-----------|
| Google Calendar | UI, pull-to-refresh, карточки | OAuth, реальные API (сейчас mock) |
| Gmail | UI, список писем, состояния | OAuth, реальные API, отправка/удаление |
| Анализ фото еды | Структура отправки | Gemini Vision (сейчас эвристика) |
| AI Chat | AIChatView, command bar | Полный UI и state management |
| Аналитика графики | Placeholder Swift Charts | Полноценные графики |
| Backend OAuth | Endpoint-пути в Config | Token storage, refresh, sessions |
| Backend LLM | /llm/plan (правила) | Реальные вызовы Gemini/GPT |

## Что не начато

| Модуль | Описание |
|--------|----------|
| Telegram/WhatsApp | Скелет моделей, auth flow нет |
| Approval Workflow | Модели определены, UI нет |
| Реестры/Каталоги | Модели есть, отображение нет |
| Kanban-доска | В ТЗ, не реализовано |
| Трекер привычек | Модели частично, UI нет |
| Pomodoro / Focus | В ТЗ, не реализовано |
| Многопользовательность | TaskSource.delegated определён, API нет |
| Очередь офлайн-записей | Структура sync есть, queue нет |
| Тесты | JarvisTests/JarvisUITests пустые |

---

## Фазы реализации

### Фаза 1. Backend OAuth Google (критический)

Кнопка «Войти через Google» работает по-настоящему.

- [ ] 1.1 GET /auth/google — URL авторизации
- [ ] 1.2 GET /auth/callback — обмен code на токены
- [ ] 1.3 Сохранение токенов (файл/SQLite + session_id)
- [ ] 1.4 GET /auth/status — проверка + auto-refresh
- [ ] 1.5 GET /auth/logout — очистка токенов
- [ ] 1.6 Клиент: обработка jarvis://auth/success
- [ ] 1.7 Клиент: session_id в UserDefaults и заголовках

### Фаза 2. Google Calendar API (критический)

Реальные события из Google Calendar.

- [ ] 2.1 GET /calendar/events — реальный Calendar API
- [ ] 2.2 POST /calendar/events — создание
- [ ] 2.3 PUT /calendar/events/{id} — обновление
- [ ] 2.4 DELETE /calendar/events/{id} — удаление
- [ ] 2.5 Клиент: session_id в pull-to-refresh

### Фаза 3. Gmail API (высокий)

Полноценная почта в приложении.

- [ ] 3.1 GET /mail/messages — список (Gmail API)
- [ ] 3.2 GET /mail/messages/{id} — тело (decode base64)
- [ ] 3.3 POST /mail/messages/send — отправка (MIME)
- [ ] 3.4 DELETE /mail/messages/{id} — удаление (trash)
- [ ] 3.5 Клиент: экран просмотра письма
- [ ] 3.6 Клиент: экран «Ответить»
- [ ] 3.7 Клиент: экран «Новое письмо»
- [ ] 3.8 Клиент: свайп-удаление

### Фаза 4. Gemini на backend (высокий)

Фото → калории от AI; анализ задач от Gemini.

- [ ] 4.1 GEMINI_API_KEY на сервере
- [ ] 4.2 POST /analyze-meal — Gemini Vision
- [ ] 4.3 POST /llm/plan — Gemini с контекстом задач
- [ ] 4.4 POST /llm/chat — универсальный чат
- [ ] 4.5 Fallback на эвристику при ошибке

### Фаза 5. Обработка ошибок (высокий)

Понятные сообщения вместо тишины при сбоях.

- [ ] 5.1 CalendarView: алерт при ошибке
- [ ] 5.2 MailView: кнопка «Повторить»
- [ ] 5.3 WellnessView: ошибка анализа фото
- [ ] 5.4 AnalyticsView: ошибка глубокого анализа
- [ ] 5.5 Общий NetworkErrorView компонент

### Фаза 6. Камера для фото блюда (средний)

Фотографирование еды прямо в приложении.

- [ ] 6.1 CameraView (PhotosPicker)
- [ ] 6.2 Кнопка «Сфотографировать» в WellnessView
- [ ] 6.3 Отправка на /analyze-meal

### Фаза 7. Развёртывание и безопасность (средний)

Стабильный и безопасный доступ к backend.

- [ ] 7.1 HTTPS (nginx + Let's Encrypt)
- [ ] 7.2 Убрать ATS exception в Release
- [ ] 7.3 Build Configuration (Debug/Release URLs)
- [ ] 7.4 Rate limiting
- [ ] 7.5 Логирование

### Фаза 8. Полировка UI (средний)

Идеальный внешний вид и поведение.

- [ ] 8.1 Иконка (все размеры)
- [ ] 8.2 Launch Screen
- [ ] 8.3 VoiceOver / Accessibility
- [ ] 8.4 Проверка уведомлений на устройстве
- [ ] 8.5 EventKit + Google Calendar в одном списке

### Фаза 9. Расширенные функции (низкий)

- [ ] 9.1 Telegram-интеграция
- [ ] 9.2 Kanban-доска
- [ ] 9.3 Трекер привычек
- [ ] 9.4 Pomodoro / Focus Timer
- [ ] 9.5 Approval Workflow UI
- [ ] 9.6 Реестры/Каталоги UI
- [ ] 9.7 Графики аналитики (Swift Charts)

### Фаза 10. Тесты (низкий)

- [ ] 10.1 Unit: PlannerStore
- [ ] 10.2 Unit: CloudSync
- [ ] 10.3 Unit: AIManager
- [ ] 10.4 UI-тесты: навигация, CRUD
- [ ] 10.5 Backend: pytest

---

## Минимальный путь к ежедневному использованию

| Приоритет | Фазы | Результат |
|-----------|-------|-----------|
| Обязательно | 1 + 2 | Календарь с реальными событиями |
| Обязательно | 4.2 + 4.3 | Фото → калории, AI-анализ |
| Обязательно | 5 | Понятные ошибки |
| Желательно | 3 | Полноценная почта |
| Желательно | 7.1 + 7.3 | HTTPS и dev/prod конфиг |
| По возможности | 6, 8 | Камера, иконка, VoiceOver |
| Позже | 9, 10 | Telegram, Kanban, тесты |

---

## Архитектура

```
JarvisApp -> StructuredMainView
  iPhone: TabView (6 вкладок)
  iPad/Mac: 3-column (sidebar + список + таймлайн)
  watchOS: упрощённый TabView

Данные: View -> PlannerStore -> SwiftData -> iCloud CloudKit
AI: Ввод -> AIManager -> [Gemini | YandexGPT | Heuristic] -> VoiceCommandExecutor
Backend: FastAPI (Python) @ 158.160.48.202:8000
```

*Обновлено: 23 марта 2026*
