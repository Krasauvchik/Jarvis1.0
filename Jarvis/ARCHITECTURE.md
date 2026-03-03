# Jarvis Planner — Architecture Documentation

> **Version:** 3.0 · **Updated:** March 2026 · **Platform:** iOS 16+ / macOS 13+ / watchOS 9+

## Overview

**Jarvis** — multi-platform task management & wellness app built with **SwiftUI**:

- **Timeline-based planning** with drag-to-reschedule (15-min snapping)
- **AI integration** — Ollama (local LLM), Gemini, Cloud GPT, heuristic fallback
- **iCloud sync** via `NSUbiquitousKeyValueStore`
- **Calendar & Mail** integration via Python backend
- **Wellness tracking** — meals, sleep, activity
- **Siri Shortcuts** via App Intents
- **Home Screen Widget** via WidgetKit

### Architecture Style

Pragmatic **MVVM** pattern:
- **Views** → SwiftUI views (platform-adaptive)
- **Store** → `PlannerStore` (observable singleton, acts as ViewModel + Repository)
- **Models** → `PlannerTask`, `DayBounds`, `TaskCategory`, `TaskTag`, wellness models
- **Services** → `CloudSync`, `AIManager`, `NotificationManager`, `CalendarSyncService`, `NetworkMonitor`

---

## UI Rule: Three Columns

**Visually there must always be 3 columns** (as on the reference screenshot):
- Left: navigation (folders)
- Middle: task list
- Right: calendar and day details

**On iPad/Mac:**
- Left and middle column widths are adjustable by dragging the divider (left: 160–400pt, middle: 240–500pt). Values persist between launches (`jarvis_sidebar_width`, `jarvis_tasklist_width`).
- Left panel can be hidden via button in sidebar header; re-shown via "stripe" button at left edge (`jarvis_sidebar_hidden`).

Changing **column order** or removing middle/right columns is **not allowed** without explicit project owner approval.

---

## Module Map

```
Jarvis/
├── JarvisApp.swift              # App entry point, iCloud init
├── StructuredMainView.swift     # PRIMARY UI (iOS/iPad/macOS layouts)
├── MainView.swift               # watchOS entry (WatchPlannerView, WatchWellnessView)
├── PlannerModels.swift          # Data models + PlannerStore (debounced save)
├── PlannerComponents.swift      # Reusable UI components
├── JarvisTheme.swift            # Theme system (light/dark adaptive)
├── AnimationExtensions.swift    # Animation modifiers & transitions
├── Config.swift                 # Configuration constants
├── AIManager.swift              # AI orchestration + intent routing (Ollama, Gemini, heuristic)
├── AIModels.swift               # AI model definitions + HeuristicAdapter
├── AIContextEngine.swift        # Cross-source semantic search (tasks, calendar, mail)
├── AILifeCoach.swift            # Personal AI coach (fitness, nutrition, learning, meditation)
├── MeetingBriefingService.swift # AI meeting briefing generator
├── VoiceCommandExecutor.swift   # Executes AIAction → PlannerStore (voice control)
├── LLMDigestService.swift       # AI digest aggregator (calendar+mail+messengers)
├── CloudSync.swift              # iCloud KV store sync
├── CalendarSyncService.swift    # EKEventKit integration
├── NotificationManager.swift    # Local notifications (15 min before task)
├── NetworkMonitor.swift         # NWPathMonitor connectivity
├── SpeechRecognizer.swift       # SFSpeechRecognizer wrapper (iOS + macOS)
├── Integrations.swift           # Auth, Calendar, Mail, Nutrition services
├── ExportImport.swift           # JSON export/import
├── WellnessModels.swift         # Wellness data models + WellnessStore
├── WellnessView.swift           # Wellness tracking UI
├── TaskStatistics.swift         # Statistics components
├── JarvisIntents.swift          # Siri Shortcuts
├── DeepLinkManager.swift        # URL scheme routing (jarvis://)
├── Localization.swift           # L10n helper for localized strings
├── Localizable.xcstrings        # String Catalog (en/ru)
├── Architecture/
│   ├── AppError.swift           # Error types & ErrorHandler
│   ├── DependencyContainer.swift # DI container
│   ├── Extensions.swift         # Date, String, Collection, View extensions
│   ├── Logger.swift             # Structured logging
│   └── Protocols.swift          # Service protocols
├── Views/
│   ├── AIChatView.swift         # AI chat dialog
│   ├── AICommandBarOverlay.swift # Inline AI command bar + voice (bottom bar)
│   ├── CalendarView.swift       # Google Calendar events (iOS)
│   ├── ChartAnalyticsView.swift # Swift Charts analytics (Phase 3)
│   ├── MailView.swift           # Gmail messages (iOS)
│   ├── MessengerSettingsView.swift   # Telegram/WhatsApp setup, auth, chat selection
│   ├── OnboardingView.swift     # 6-page onboarding + OnboardingManager
│   ├── ProfileSleepViews.swift  # Profile & sleep calculator sheets
│   ├── ProjectsView.swift       # Projects + sub-tasks (Phase 3)
│   ├── SettingsViews.swift      # Settings sheet (iOS/Mac)
│   ├── SidebarView.swift        # Sidebar navigation + AppMode (iPad/Mac)
│   ├── TaskSheets.swift         # Task creation/edit sheets
│   └── TimelineView.swift       # Timeline panel (iPad/Mac)
└── JarvisWidgetExtension/
    └── JarvisWidget.swift       # Home Screen widget
```

---

## Data Flow

```
┌─────────────┐    ┌──────────────┐    ┌──────────────┐
│  SwiftUI    │───▶│ PlannerStore │───▶│ UserDefaults │
│  Views      │◀───│   (shared)   │    │ + App Group  │
└─────────────┘    └──────────────┘    └──────────────┘
                         │  ▲                  
                         │  │                  
                         ▼  │                  
                   ┌──────────────┐    ┌──────────────┐
                   │  CloudSync   │◀──▶│   iCloud     │
                   │   (shared)   │    │   KV Store   │
                   └──────────────┘    └──────────────┘
                         │
                         ▼
                   ┌──────────────┐
                   │ NetworkMonitor│ ← reconnect triggers sync
                   └──────────────┘
```

**Write path:** View → `store.add/update/delete()` → `save()` (debounced 300 ms) → `persistNow()` → UserDefaults + CloudSync + Widget Data  
**Read path:** `PlannerStore.init()` → CloudSync (preferred) ⟶ UserDefaults (fallback) → `@Published tasks`  
**Sync path:** iCloud change notification → `loadFromCloud()` → replaces `@Published` state

---

## Data Model

### PlannerTask (primary entity)

| Field | Type | Description |
|-------|------|-------------|
| `id` | `UUID` | Immutable unique identifier |
| `title` | `String` | Task title |
| `notes` | `String` | Optional notes |
| `date` | `Date` | Scheduled date/time |
| `durationMinutes` | `Int` | Duration (default: 30) |
| `isCompleted` | `Bool` | Completion status |
| `isInbox` | `Bool` | True = unscheduled inbox item |
| `isAllDay` | `Bool` | All-day event flag |
| `colorIndex` | `Int` | Index into `JarvisTheme.taskColors` |
| `icon` | `TaskIcon` | SF Symbol name |
| `priority` | `TaskPriority` | high/medium/low/none |
| `categoryId` | `UUID?` | Optional category link |
| `tagIds` | `[UUID]` | Tag references |
| `recurrenceRule` | `RecurrenceRule?` | daily/weekdays/weekends/weekly/monthly/yearly |
| `completedRecurrenceDates` | `[Date]` | Dates where recurring task was completed |
| `hasAlarm` | `Bool` | Notification enabled |
| `calendarEventId` | `String?` | Linked EKEvent identifier |

### Supporting Models

- **TaskCategory** — `id`, `name`, `colorIndex`, `icon`
- **TaskTag** — `id`, `name`, `colorHex`
- **DayBounds** — `riseHour/Minute`, `windDownHour/Minute`
- **MealEntry / SleepEntry / ActivityEntry** — wellness tracking

---

## Persistence & Sync

### Storage Layers

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Local** | `UserDefaults` | Primary local storage (`jarvis_tasks_v4`) |
| **Widget** | `UserDefaults(suiteName:)` | App Group shared with widget |
| **Cloud** | `NSUbiquitousKeyValueStore` | Cross-device iCloud sync |

### Storage Keys

| Key | Version | Content |
|-----|---------|---------|
| `jarvis_tasks_v4` | v4 | All tasks as JSON |
| `jarvis_wellness_v3` | v3 | Wellness snapshot |
| `jarvis_categories_v1` | v1 | Categories |
| `jarvis_tags_v1` | v1 | Tags |
| `dayBounds_*` | — | Individual KV pairs |
| `aiModel_v2` | v2 | Selected AI model |

### Sync Strategy

- **Write:** Save to UserDefaults → CloudSync.saveTasks → kvStore.synchronize()
- **Read:** Cloud first → UserDefaults fallback
- **Conflict:** Last-write-wins (no merge)
- **Reconnect:** NetworkMonitor detects connectivity → forceSync()

---

## AI Layer

```
┌────────────┐
│ AIManager  │──── selectedModel ────┐
└────────────┘                       │
        │                              ▼
        ├── .heuristic ──▶ HeuristicAdapter (offline, instant)
        ├── .ollama ─────▶ Backend /ai/* → Ollama (localhost:11434)
        ├── .cloudGPT ───▶ Backend /ai/* → Cloud LLM → Ollama → heuristic
        ├── .gemini ─────▶ (reserved, backend-based)
        └── .onDeviceLarge ▶ Local / Ollama-like (future)
                         │
                         ▼ (intent routing)
        ┌────────────┼─────────────┬──────────────┬───────────────┐
        │            │             │              │               │
    context     briefing       coaching     delegation      general
        ▼            ▼             ▼              ▼               ▼
 AIContext    MeetingBrief   AILifeCoach   /ai/delegate    sendCommand
  Engine       Service                      -task
```

- **HeuristicAdapter:** Extracts tasks from natural language (Russian + English), pattern matching for time/dates.
- **Cloud LLM (Cloud GPT/GPT‑class):** Configured on backend via env (`JARVIS_CLOUD_LLM_API_KEY`, `JARVIS_CLOUD_LLM_MODEL`, `JARVIS_CLOUD_LLM_BASE_URL`) и используется как первый слой для `/llm/plan`, `/llm/chat`, `/ai/command`, `/ai/digest`, Telegram/WhatsApp дайджестов.
- **Ollama:** Local LLM via HTTP (`/api/generate` and `/api/chat`), configurable model and base URL; служит fallback’ом, если Cloud LLM недоступен, и основным движком в локальном режиме.
- **AIContextEngine:** Cross-source semantic search across tasks, calendar, mail, messengers (через backend `/ai/context-search`).
- **MeetingBriefingService:** Generates briefings for upcoming meetings (participants, agenda, context) через `/ai/meeting-briefing` → LLM.
- **AILifeCoach:** Personal coaching (fitness, nutrition, learning, meditation categories) поверх LLM.
- **Intent Routing:** `AIManager.detectIntent()` classifies user messages into 5 intents: contextSearch, meetingBriefing, coaching, delegation, standard.
- **Chat:** Работает через backend `/llm/chat`, который сначала использует Cloud LLM, а затем Ollama как fallback.

### LLM Availability Rule

- **Product rule:** каждое новое изменение/фича в Jarvis должно быть:
    - Описано в архитектурной документации (этот файл + профиль AI в коде),
    - Протянуто в AI-слой так, чтобы LLM могло:
        - Понимать новые сущности/папки/режимы в подсказках и системных промптах,
        - Отвечать на вопросы пользователя про эти сущности,
        - По возможности вызывать соответствующие действия (через `AIManager` → backend `/ai/*`), если это безопасно.
- Практически это означает, что при добавлении новой папки, статуса, режима или сервиса мы:
    - Обновляем этот документ (раздел навигации/данных),
    - Обновляем подсказки/описания, которые попадают в контекст LLM (например, форматтеры в `AIContextEngine`, промпты MeetingBriefing/Coach),
    - При необходимости расширяем intent routing (`UserIntent`) и backend-команды.

---

## Theme System

```
ThemeMode (.light/.dark/.system)
    │
    ▼
ThemeManager (singleton, persists to UserDefaults)
    │
    ▼
JarvisTheme(isDark: Bool) ← adaptive instance
    │
    ├── .background, .cardBackground, .textPrimary, etc. (instance properties — adaptive)
    ├── Static color-scheme-aware properties (use @Environment(\.colorScheme))
    └── .accent, .taskColors, .Dimensions (static, theme-independent)
```

**Usage:**
```swift
// Instance-based (correct):
let theme = JarvisTheme.current(for: colorScheme)
theme.textPrimary  // adapts to light/dark

// Static (also adaptive via colorScheme):
JarvisTheme.textPrimary  // reads system color scheme
```

---

## Navigation Architecture

| Platform | Layout | Details |
|----------|--------|---------|
| **iPhone** | `TabView` | Sections: Tasks, Wellness, Calendar, Mail, AI Chat, Analytics, Settings |
| **iPad / Mac** | 3-column `HStack` | Sidebar + Task List + Timeline |
| **watchOS** | Simplified `TabView` | Planner + Wellness |

---

### Sidebar Sections (Folders)

Навигационные папки в сайдбаре и вкладки на iPhone используются как **стабильные концепции**, с которыми LLM должно уметь работать (понимать и объяснять пользователю):

- **Inbox** (`NavigationSection.inbox`)
    - За что отвечает: входящий ящик для всех новых задач, которые ещё не запланированы по времени.
    - Почему есть: помогает быстро «скидывать» идеи и дела без выбора даты; позже пользователь (или LLM по голосовой команде) раскладывает их по дням.

- **Today** (`.today`)
    - За что отвечает: все задачи, запланированные на текущий день (с учётом времени и all‑day).
    - Почему есть: главный рабочий контекст на сегодня; всё, что пользователь реально должен увидеть и сделать в текущий день.

- **Scheduled** (`.scheduled`)
    - За что отвечает: все запланированные задачи с конкретной датой/временем (будущее и ближайшие дни), кроме Inbox.
    - Почему есть: даёт обзор загруженности по датам и помогает быстро перераспределять задачи, не уходя в календарный режим.

- **Future Plans** (`.futurePlans`, Personal mode)
    - За что отвечает: задачи и планы, которые находятся дальше ближайшего горизонта (например, после завтра/следующей недели), не требуют немедленного внимания.
    - Почему есть: отдельная «полка» для долгосрочных и личных планов; разгружает Today/Scheduled, но позволяет LLM и пользователю не терять стратегические цели.

- **Completed** (`.completed`)
    - За что отвечает: все выполненные задачи.
    - Почему есть: история выполнения и база для аналитики/рефлексии; LLM может использовать это для брифингов, обзоров недели и лайф‑коучинга.

- **All Tasks** (`.all`)
    - За что отвечает: полный список всех задач (активных и выполненных).
    - Почему есть: «сырое» представление данных для поиска, аудита и массовых операций; полезно для AI‑поиска и контекста.

- **Health / Wellness** (`.health`, Personal mode)
    - За что отвечает: доступ к wellness‑модулю (питание, сон, активность, вода).
    - Почему есть: Jarvis — не только планер, но и ассистент по самочувствию; LLM (через AILifeCoach) использует эти данные для советов и персональных планов.

- **Calendar** (`.calendarSection`)
    - За что отвечает: интеграция с Google Calendar (просмотр и управление событиями).
    - Почему есть: единое пространство, где задачи и встречи связаны; LLM может создавать/изменять события через `/ai/command`.

- **Mail** (`.mailSection`)
    - За что отвечает: просмотр Gmail и связанные действия (ответить, найти письмо и т.д.).
    - Почему есть: связка задач и почты; LLM может искать контекст в письмах и предлагать действия.

- **Messengers** (`.messengers`)
    - За что отвечает: интеграция с Telegram/WhatsApp (дайджесты, в будущем делегирование задач).
    - Почему есть: многие задачи рождаются и обсуждаются в мессенджерах; LLM через `/ai/digest` и `/ai/context-search` поднимает этот контекст.

- **Analytics** (`.analytics`, Work mode)
    - За что отвечает: аналитика по задачам, времени и выполнению (ChartAnalyticsView, фаза 3).
    - Почему есть: помогает видеть тренды продуктивности и использовать их в коучинге/планировании с помощью LLM.

- **Projects** (`.projects`, Work mode)
    - За что отвечает: представление задач в разрезе проектов (фаза 3, связка `Project` + подзадачи).
    - Почему есть: даёт более высокоуровневую структуру, чем отдельные задачи; LLM может оперировать проектами как сущностями.

- **AI Chat / Neural** (`.chat`)
    - За что отвечает: диалоговый интерфейс с LLM (вопросы, команды, коучинг).
    - Почему есть: основной способ общаться с Jarvis‑ИИ естественным языком; многие действия (перенос задач, создание событий, поиск контекста) запускаются именно отсюда.

- **Custom Folders / Categories** (`TaskCategory`, раздел Categories в Sidebar)
    - За что отвечает: пользовательские папки для группировки задач (работа, семья, хобби и т.д.).
    - Почему есть: позволяет пользователю строить свою собственную систему папок, поверх базовых секций; LLM может ссылаться на категории по имени (например, «покажи задачи по категории Работа на сегодня»), так как каждая задача несёт `categoryId`.

## Key Services

| Service | File | Purpose |
|---------|------|---------|
| `PlannerStore` | PlannerModels.swift | Task CRUD, query, persistence (cached) |
| `CloudSync` | CloudSync.swift | iCloud KV sync |
| `AIManager` | AIManager.swift | AI model orchestration + intent routing |
| `AIContextEngine` | AIContextEngine.swift | Cross-source semantic search |
| `MeetingBriefingService` | MeetingBriefingService.swift | Meeting briefing generation |
| `AILifeCoach` | AILifeCoach.swift | Personal AI coaching (fitness, nutrition, etc.) |
| `VoiceCommandExecutor` | VoiceCommandExecutor.swift | Executes AI actions in PlannerStore |
| `LLMDigestService` | LLMDigestService.swift | AI digest from calendar+mail+messengers |
| `CalendarSyncService` | CalendarSyncService.swift | EKEventKit sync |
| `NotificationManager` | NotificationManager.swift | Local notifications (15 min early) |
| `NetworkMonitor` | NetworkMonitor.swift | Connectivity monitoring |
| `SpeechRecognizer` | SpeechRecognizer.swift | Speech-to-text (iOS + macOS) |
| `AuthService` | Integrations.swift | Backend auth check |
| `CalendarService` | Integrations.swift | Backend calendar API |
| `MailService` | Integrations.swift | Backend mail API |
| `NutritionService` | Integrations.swift | Meal analysis API |
| `ExportImport` | ExportImport.swift | JSON export/import |

---

## Voice Control & LLM Integration

### Architecture

```
User Voice ──▶ SpeechRecognizer (SFSpeech) ──▶ AIManager.sendCommand()
                                                       │
                   ┌───────────────────────────────────┤
                   ▼                                   ▼
            Backend /ai/command              Direct Ollama (fallback)
            (Ollama + JSON format)
                   │
                   ▼
          AICommandResponse { response, actions[], executed[] }
                   │
                   ▼
          VoiceCommandExecutor.execute(actions)
                   │
       ┌───────────┼───────────┬──────────────┬────────────┐
       ▼           ▼           ▼              ▼            ▼
  create_task  complete_task  move_task  reschedule_task  delete_task
  (PlannerStore.add)  (.toggleCompletion)  (.moveTask)  (.update)  (.delete)
```

### Supported Voice Commands

| Intent | Example | AI Action |
|--------|---------|-----------|
| Create task | "Создай задачу купить молоко завтра в 10" | `create_task` |
| Complete task | "Отметь задачу молоко как выполненную" | `complete_task` |
| Delete task | "Удали задачу уборка" | `delete_task` |
| Reschedule | "Перенеси встречу на послезавтра" | `reschedule_task` |
| Move to folder | "Перенеси задачу во входящие" | `move_task` |
| Show calendar | "Покажи мой календарь" | `show_calendar` |
| Show mail | "Есть непрочитанные?" | `show_mail` |
| Send email | "Отправь письмо..." | `send_email` |
| AI digest | "Покажи сводку/выдержку" | Triggers `LLMDigestService` |
| General chat | "Какие дела на сегодня?" | `advice` / free text |

### LLM Digest Pipeline

```
LLMDigestService.generateDigest()
    ├── CalendarService.fetchEventsAsDTO()    (Google Calendar)
    ├── MailService.fetchMessages()           (Gmail)
    ├── Backend /integrations/telegram/digest (Telethon MTProto → selected chats → LLM)
    └── Backend /integrations/whatsapp/digest (Green API → selected chats → LLM)
           │
           ▼
    buildDigestContext() → structured text
           │
           ▼
    Backend /ai/digest (Ollama) → AI summary

### Messenger Integration Architecture

```
┌─────────────────────────────────────────────────┐
│                 iOS/macOS App                    │
│  MessengerSettingsView                          │
│    ├── TelegramSetupSection (auth flow + chats) │
│    └── WhatsAppSetupSection (credentials + QR)  │
└──────────────────┬──────────────────────────────┘
                   │ REST API
┌──────────────────▼──────────────────────────────┐
│              FastAPI Backend                      │
│  /integrations/telegram/*                        │
│    └── telegram_service.py (TelegramService)     │
│         └── Telethon (MTProto user client)        │
│              • Authenticates as user (phone+code) │
│              • Reads ONLY selected chats           │
│              • Session persisted on disk            │
│  /integrations/whatsapp/*                          │
│    └── whatsapp_service.py (WhatsAppService)       │
│         └── Green API (REST bridge to WA Web)      │
│              • User scans QR on green-api.com       │
│              • Reads ONLY selected chats             │
└──────────────────┬──────────────────────────────────┘
                   │ LLM Summarization
┌──────────────────▼──────────┐
│  Ollama (llama3.2 local)    │
│  Raw messages → AI digest    │
└─────────────────────────────┘
```

**Telegram Setup Flow:**
1. User gets `api_id` + `api_hash` from https://my.telegram.org/apps
2. POST `/telegram/configure` → saves credentials
3. POST `/telegram/auth/start` → sends SMS/Telegram code
4. POST `/telegram/auth/complete` → verifies code (+ optional 2FA)
5. GET `/telegram/chats` → lists all dialogs
6. POST `/telegram/chats/select` → user picks which chats to monitor
7. GET `/telegram/digest` → reads selected chats → LLM summary

**WhatsApp Setup Flow:**
1. User registers at https://green-api.com
2. Scans QR code in Green API dashboard
3. POST `/whatsapp/configure` → saves instance_id + api_token
4. GET `/whatsapp/chats` → lists all chats
5. POST `/whatsapp/chats/select` → user picks chats
6. GET `/whatsapp/digest` → reads selected chats → LLM summary
```

### Task Search (Fuzzy)

`VoiceCommandExecutor.findTask(byTitle:)` searches in 3 steps:
1. Exact match (case-insensitive)
2. Contains match (prioritizes non-completed tasks)
3. Word intersection match (shared words > 2 chars)

---

## Widget

**File:** `JarvisWidgetExtension/JarvisWidget.swift`

- **Type:** `StaticConfiguration` (timeline-based)
- **Refresh:** Every 15 minutes (system-throttled)
- **Data:** Reads from `UserDefaults(suiteName: Config.appGroupSuite)`
- **Display:** Up to 4 upcoming tasks with times and colors
- **Sizes:** `.systemSmall`, `.systemMedium`

---

## Backend

**Location:** `jarvis-backend/`  
**Stack:** Python FastAPI

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/auth/status` | GET | Check Google auth |
| `/auth/google` | GET | Initiate Google OAuth |
| `/calendar/events` | GET | Fetch Google Calendar events |
| `/mail/messages` | GET | Fetch Gmail messages |
| `/mail/send` | POST | Send Gmail message |
| `/mail/reply` | POST | Reply to Gmail message |
| `/analyze-meal` | POST | Nutrition analysis |
| `/llm/plan` | POST | AI task advice |
| `/llm/chat` | POST | LLM chat proxy (Ollama) |
| `/ai/command` | POST | Unified AI command (voice/text → actions) |
| `/ai/digest` | POST | AI digest aggregation (all sources → summary) |
| `/integrations/telegram/status` | GET | Telegram connection status |
| `/integrations/telegram/configure` | POST | Save Telegram API credentials |
| `/integrations/telegram/auth/start` | POST | Send auth code to phone |
| `/integrations/telegram/auth/complete` | POST | Verify code (+2FA) |
| `/integrations/telegram/chats` | GET | List available chats |
| `/integrations/telegram/chats/select` | POST | Select chats to monitor |
| `/integrations/telegram/digest` | GET | LLM-summarized digest from selected chats |
| `/integrations/telegram/disconnect` | POST | Logout & clear session |
| `/integrations/whatsapp/status` | GET | WhatsApp connection status |
| `/integrations/whatsapp/configure` | POST | Save Green API credentials |
| `/integrations/whatsapp/qr` | GET | Get QR code (if needed) |
| `/integrations/whatsapp/chats` | GET | List available chats |
| `/integrations/whatsapp/chats/select` | POST | Select chats to monitor |
| `/integrations/whatsapp/digest` | GET | LLM-summarized digest from selected chats |
| `/integrations/whatsapp/disconnect` | POST | Disconnect & clear session |

**Auth:** Google OAuth2 (credentials.json)  
**Deploy:** Docker / systemd service

---

## Features

### Task Management
- ✅ Task creation (title, notes, date, duration, icon, color, priority)
- ✅ Inbox — unscheduled tasks for later planning
- ✅ Completion (checkbox, swipe)
- ✅ Editing (tap or context menu)
- ✅ Deletion (swipe left, context menu)
- ✅ Duplication
- ✅ Move to tomorrow
- ✅ Color picker (8 colors)
- ✅ Icon picker (40+ icons)
- ✅ Recurring tasks (daily/weekdays/weekends/weekly/monthly/yearly)
- ✅ Categories and tags
- ✅ Drag & drop (to timeline, to calendar, to inbox)
- ✅ Timeline drag-to-reschedule (15-min snapping)

### Wellness
- ✅ Meal logging with calorie tracking
- ✅ Sleep tracking
- ✅ Activity logging
- ✅ Sleep calculator (90-min cycles, 14-min falling asleep)

### Integrations
- ✅ iCloud sync
- ✅ Google Calendar (via backend)
- ✅ Gmail (via backend)
- ✅ EKEventKit local calendar sync
- ✅ Local notifications
- ✅ Siri Shortcuts (add task, show today)
- ✅ Widget (with deep-link taps)
- ✅ Export/Import JSON
- ✅ WhatsApp (via wa.me deep link)
- ✅ Telegram (Bot API send/receive)

### Analytics
- ✅ Swift Charts dashboard (iOS 16+ / macOS 13+)
- ✅ Completion trend (bar chart, by period)
- ✅ Productivity by hour of day
- ✅ Category distribution (horizontal bar chart)
- ✅ Priority breakdown (bar chart)
- ✅ Streak tracker (14-day dot grid)
- ✅ AI advice section
- ✅ Summary cards (total / completed / avg per day / streak)

### Projects & Sub-tasks
- ✅ Project model (name, description, color, icon, archive)
- ✅ Sub-task hierarchy (parentTaskId on PlannerTask)
- ✅ Project card grid with progress bars
- ✅ Inline sub-task list (add / toggle / delete)

### Deep Linking
- ✅ `jarvis://` URL scheme (task, today, inbox, add, analytics, chat, calendar, mail, messengers)
- ✅ Widget tap → deep link routing
- ✅ Notification tap → task deep link
- ✅ Registered in Info.plist

### Localization
- ✅ String Catalog (`Localizable.xcstrings`) — Russian (source) + English
- ✅ `L10n` helper enum (~90 keys)
- ⬜ Full view wiring (hardcoded strings → L10n references)

### Theming
- ✅ Light / Dark / System themes
- ✅ Instant switching
- ✅ Persisted to UserDefaults

### App Modes
- ✅ Work / Personal mode switching
- ✅ Filtered sidebar navigation per mode
- ✅ Mode persisted via @AppStorage

### Accessibility
- ✅ VoiceOver labels on all key interactive elements
- ✅ Dynamic Type support (capped at accessibility1 for complex layouts)
- ✅ Accessibility hints on primary actions

### macOS Integration
- ✅ Keyboard shortcuts via Commands API
- ✅ Native window management
- ✅ Sidebar toggle (Ctrl+⌘S)

---

## Privacy & Data Protection

> **Принцип:** приватность пользователя — first-class citizen. Jarvis спроектирован так, что персональные данные остаются под контролем владельца: на устройстве, в его iCloud и на его собственном backend-сервере.

### 1. Хранение данных на устройстве

| Данные | Где хранятся | Шифрование |
|--------|-------------|------------|
| Задачи, категории, теги, проекты | SwiftData (SQLite) в контейнере приложения | iOS/macOS Data Protection (AES-256, привязано к Secure Enclave) |
| Wellness (питание, сон, активность) | SwiftData | То же |
| Вложения задач (фото/файлы) | `Documents/TaskAttachments/` | iOS Data Protection (Complete Until First User Authentication) |
| Настройки и предпочтения | `UserDefaults` / `@AppStorage` | Keychain-уровня нет, но внутри sandbox |
| Виджет-данные | `UserDefaults(suiteName: appGroup)` | App Group песочница |

- Все данные находятся внутри **песочницы приложения** (App Sandbox) — другие приложения не имеют к ним доступа.
- Файлы-вложения **не загружаются** на внешние серверы; они существуют только на устройстве (и, при включении, в iCloud Drive контейнере).

### 2. Синхронизация (iCloud)

| Канал | Что передаётся | Шифрование |
|-------|---------------|------------|
| iCloud KV Store (`NSUbiquitousKeyValueStore`) | JSON-задач, категории, теги, настройки AI | TLS в транзите + Apple server-side шифрование |
| CloudKit (SwiftData) | Все SwiftData-сущности | TLS + Apple CloudKit encryption |

- Apple не имеет доступа к расшифрованным данным CloudKit (end-to-end для Advanced Data Protection).
- Пользователь может **отключить iCloud** для Jarvis в настройках системы — приложение продолжит работать локально (fallback в `DataPersistence`).

### 3. Backend-сервер

| Аспект | Как устроено |
|--------|-------------|
| Владение | Сервер принадлежит разработчику (VPS 158.160.48.202); никакие третьи стороны не имеют доступа |
| Транспорт | HTTPS (TLS) — самоподписанный сертификат / Let's Encrypt |
| Хранение на диске | `credentials.json` (Google OAuth токены), `messenger_config.json` (Telegram/WhatsApp токены + ID выбранных чатов) |
| Сообщения/письма/события | **Не сохраняются** — подтягиваются из API Google/Telegram/WhatsApp по запросу, обрабатываются в памяти, возвращаются клиенту |
| Логирование | Логируются только ошибки и метаданные (endpoint, статус); содержимое писем/сообщений **не логируется** |

#### Что хранится на backend (и ничего больше):

```
credentials.json          ← Google OAuth refresh token (используется Calendar/Gmail API)
messenger_config.json     ← Telegram api_id/api_hash/phone + WhatsApp instance_id/token
                             + списки выбранных чатов (ID, не содержимое)
telegram_session.session  ← Telethon session file (Telegram MTProto auth)
```

- **Нет базы данных** на сервере. Нет хранения задач, нет хранения переписок.
- При перезапуске сервера теряется только in-memory состояние; все «знания» о задачах живут на устройстве.

### 4. LLM и AI-провайдеры

| Режим | Куда уходят данные | Что именно |
|-------|-------------------|------------|
| **Ollama (локальный)** | Никуда — `localhost:11434` на том же сервере | Текст задач + контекст для промпта |
| **Cloud LLM (OpenAI и т.п.)** | На сервер провайдера (api.openai.com и т.д.) | Текст задач, краткие выписки из календаря/почты/мессенджеров — **только то, что нужно для конкретного запроса** |
| **Heuristic** | Никуда — выполняется локально на устройстве | Ничего не покидает устройство |

#### Контроль пользователя:

- Выбор модели в настройках (`Settings → AI Model`):
  - `.heuristic` — **полностью оффлайн**, данные никуда не уходят
  - `.ollama` — данные уходят только на **ваш собственный сервер**
  - `.cloudGPT` — данные уходят на ваш сервер → оттуда в Cloud LLM провайдер
- Если переменная `JARVIS_CLOUD_LLM_API_KEY` **не задана** на backend, облачный LLM не используется даже при выборе `.cloudGPT` (fallback на Ollama).

### 5. Интеграции с внешними сервисами

| Сервис | Доступ | Что видит Jarvis | Что НЕ делает |
|--------|--------|-----------------|---------------|
| **Google Calendar** | OAuth 2.0 (scope: `calendar.events`) | События: title, date, attendees, description | Не модифицирует без команды пользователя |
| **Gmail** | OAuth 2.0 (scope: `gmail.readonly`, `gmail.send`) | Письма: subject, from, snippet, body (при запросе) | Не удаляет, не пересылает автоматически |
| **Telegram** | MTProto (Telethon, user-авторизация) | Сообщения **только из выбранных пользователем чатов** | Не читает чаты, которые пользователь не выбрал; не отправляет сообщений |
| **WhatsApp** | Green API REST | Сообщения **только из выбранных чатов** | То же — только чтение выбранных чатов |

- Пользователь **явно авторизует** каждый сервис (Google OAuth, Telegram код, WhatsApp QR).
- Пользователь **явно выбирает** чаты для мониторинга (через UI `MessengerSettingsView`).
- Никакие данные не собираются «в фоне» без действий пользователя.

### 6. Вложения (Attachments)

- Файлы/фото хранятся **только локально** в `Documents/TaskAttachments/` на устройстве.
- Файл копируется из source (Files / Photos) в контейнер приложения; оригинал не модифицируется.
- Метаданные вложения (`TaskAttachment`: имя, тип, путь, размер, дата) хранятся в SwiftData вместе с задачей.
- Вложения **не отправляются** на backend, в LLM-промпты или в iCloud (если не включён iCloud Drive для контейнера).

### 7. Рекомендации для продакшна

| Мера | Статус | Приоритет |
|------|--------|-----------|
| TLS между клиентом и backend | Реализовано (self-signed / Let's Encrypt) | Высокий |
| Шифрование `credentials.json` и `messenger_config.json` на диске | Не реализовано — рекомендуется file-level encryption или HashiCorp Vault | Средний |
| Ротация Google OAuth refresh token | Не реализовано — рекомендуется периодическая ротация | Средний |
| Rate limiting на API-эндпоинтах | Не реализовано — рекомендуется FastAPI middleware | Средний |
| Аутентификация клиент → backend | Не реализовано (backend доступен по IP) — рекомендуется API key или mTLS | Высокий |
| Audit log (кто/когда/что запрашивал) | Не реализовано — рекомендуется structured logging | Низкий |
| GDPR/data export: кнопка «Экспорт всех моих данных» | Частично (Export/Import JSON для задач) — расширить на wellness + attachments | Низкий |
| Кнопка «Удалить все мои данные» | Не реализовано — рекомендуется full wipe (SwiftData + backend tokens) | Средний |

### 8. Краткая сводка

```
┌──────────────────────────────────────────────────────────────────┐
│                      JARVIS DATA FLOW                           │
│                                                                  │
│  ┌─────────┐   TLS    ┌─────────────┐   TLS    ┌────────────┐  │
│  │  Device  │◄───────►│   Backend   │◄────────►│  Cloud LLM │  │
│  │(SwiftData│         │ (FastAPI)   │          │ (optional)  │  │
│  │ sandbox) │         │ no DB       │          └────────────┘  │
│  └────┬─────┘         │ no msg logs │                          │
│       │               └──────┬──────┘                          │
│       │ iCloud                │                                 │
│       ▼                      │                                 │
│  ┌─────────┐          ┌──────┴──────┐                          │
│  │CloudKit │          │ Google API  │                          │
│  │(Apple)  │          │ Telegram    │                          │
│  └─────────┘          │ WhatsApp    │                          │
│                       └─────────────┘                          │
│                                                                  │
│  Задачи/wellness → device only + iCloud                         │
│  Вложения → device only                                         │
│  Переписки/письма → in-memory, не сохраняются                  │
│  LLM-контекст → ваш сервер, опционально Cloud LLM              │
└──────────────────────────────────────────────────────────────────┘
```

---

## Known Limitations

1. **iCloud KV Store 1MB limit** — all data serialized as JSON; will fail silently with ~200-300 tasks
2. **No data migration** — storage key version bumps abandon old data
3. **No conflict resolution** — last-write-wins on iCloud sync
4. **Localization partial** — L10n infrastructure ready but most views still use hardcoded Russian strings
5. **Calendar/Mail iOS-only** — unavailable on macOS/watchOS
6. **Telegram/WhatsApp send** — delegation endpoint exists but actual messenger send not yet implemented

---

## Development Roadmap

### Phase 1 — Stability & Quality ✅
- [x] Fix timeline task positioning
- [x] Add drag-to-reschedule (15-min snapping)
- [x] Cache DateFormatters
- [x] Fix PlannerStore singleton usage
- [x] Fix theme system (adaptive light/dark)
- [x] Fix force-unwrap crash in HeuristicAdapter
- [x] Add error logging to critical save/sync paths
- [x] Fix notification timing (15 min before task)
- [x] Improve CloudSync reliability
- [x] Add accessibility labels to key components
- [x] Add input validation for tasks/wellness

### Phase 2 — Architecture Cleanup ✅
- [x] Split StructuredMainView.swift into focused files
- [x] Migrate from singletons to proper DI via DependencyContainer
- [x] Connect UseCases layer or simplify
- [x] Unify Repository pattern with PlannerStore
- [x] Remove dead code (TaskStatistics.swift, _deprecated/)

### Phase 3 — Features
- [ ] CloudKit migration (replaces KV store, removes 1MB limit)
- [x] Deep linking from widget/notifications to specific tasks
- [x] Chart-based analytics (Swift Charts)
- [x] Localization infrastructure (en/ru)
- [x] Projects/sub-tasks
- [ ] Collaborative task sharing

### Phase 4 — Polish
- [x] Full VoiceOver accessibility audit
- [x] Dynamic Type support
- [x] Onboarding flow
- [x] Global error handling (ErrorHandler wired to root view)
- [x] macOS keyboard shortcuts (⌘N, ⌘D, ⌘I, ⇧⌘A, ⌘L, ⌃⌘S)
- [x] Validation error feedback (WellnessView, nutrition photo)

### Phase 5 — AI-First Experience ✅
- [x] AI intent routing (context search, briefing, coaching, delegation, general)
- [x] AIContextEngine — cross-source semantic search
- [x] MeetingBriefingService — meeting briefing generation
- [x] AILifeCoach — personal coaching (fitness, nutrition, learning, meditation)
- [x] Task delegation model (TaskDelegation, TaskSource)
- [x] Backend endpoints (/ai/context-search, /ai/meeting-briefing, /ai/delegate-task)
- [x] Inline AI command bar (voice + text + quick action chips)
- [x] AIWelcomeHeader on Today tab
- [x] Voice-first UI (mic button, speech recognition, auto-execute)

### Phase 6 — Production Readiness ✅
- [x] Full L10n wiring — 580+ keys in Localization.swift, wired in 15+ view files
- [x] Localization updated — Localizable.xcstrings with 795 entries (ru + en)
- [x] NavigationSection & AppMode enums use localizedName (no hardcoded Russian rawValues)
- [x] HTTPS backend — TLS certificates (self-signed), uvicorn --ssl, all endpoints https://
- [x] Unit tests expanded — 92 tests (PlannerStore, L10n, NavigationSection, AppMode, Wellness, Crash, Logger, etc.)
- [x] Performance tracker — PerformanceTracker (span timing, metrics, slow-op warnings)
- [x] Crash reporter — CrashReporter (signal handlers, exception handler, non-fatal recording, local report storage)
- [x] App launch tracker — AppLaunchTracker (cold launch time, session count)
- [x] App Store preparation — Info.plist (privacy descriptions, ATS exceptions, productivity category)
- [x] ATS exceptions for localhost (Ollama), backend IP, domain
- [x] NSLocalNetworkUsageDescription for Ollama LLM access

### Phase 7 — Future Enhancements
- [ ] CloudKit migration (remove 1MB NSUbiquitousKeyValueStore limit)
- [ ] Actual Telegram/WhatsApp delegation message sending
- [ ] Firebase/Sentry cloud crash analytics (currently local-only)
- [ ] Performance profiling with Instruments (Core Animation, Time Profiler)
- [ ] App Store screenshots and preview video
- [ ] TestFlight beta distribution
