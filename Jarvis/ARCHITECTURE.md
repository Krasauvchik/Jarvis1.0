# Jarvis Planner — Architecture Documentation

> **Version:** 2.0 · **Updated:** June 2025 · **Platform:** iOS 16+ / macOS 13+ / watchOS 9+

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
├── AIManager.swift              # AI orchestration (Ollama, Gemini, heuristic)
├── AIModels.swift               # AI model definitions + HeuristicAdapter
├── CloudSync.swift              # iCloud KV store sync
├── CalendarSyncService.swift    # EKEventKit integration
├── NotificationManager.swift    # Local notifications (15 min before task)
├── NetworkMonitor.swift         # NWPathMonitor connectivity
├── SpeechRecognizer.swift       # SFSpeechRecognizer wrapper
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
│   ├── CalendarView.swift       # Google Calendar events (iOS)
│   ├── ChartAnalyticsView.swift # Swift Charts analytics (Phase 3)
│   ├── MailView.swift           # Gmail messages (iOS)
│   ├── MessengerIntegrationView.swift # WhatsApp/Telegram sharing
│   ├── ProjectsView.swift       # Projects + sub-tasks (Phase 3)
│   ├── SettingsViews.swift      # Settings sheet (iOS/Mac)
│   ├── SidebarView.swift        # Sidebar navigation (iPad/Mac)
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
      ├── .ollama ─────▶ Ollama HTTP API (localhost:11434)
      ├── .gemini ─────▶ Backend /llm/plan
      └── .cloudGPT ───▶ Backend /llm/plan
```

- **HeuristicAdapter:** Extracts tasks from natural language (Russian + English), pattern matching for time/dates
- **Ollama:** Local LLM via HTTP (`/api/generate` and `/api/chat`), configurable model and base URL
- **Chat:** Currently Ollama-only for full dialog mode

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

## Key Services

| Service | File | Purpose |
|---------|------|---------|
| `PlannerStore` | PlannerModels.swift | Task CRUD, query, persistence |
| `CloudSync` | CloudSync.swift | iCloud KV sync |
| `AIManager` | AIManager.swift | AI model orchestration |
| `CalendarSyncService` | CalendarSyncService.swift | EKEventKit sync |
| `NotificationManager` | NotificationManager.swift | Local notifications (15 min early) |
| `NetworkMonitor` | NetworkMonitor.swift | Connectivity monitoring |
| `SpeechRecognizer` | SpeechRecognizer.swift | Speech-to-text |
| `AuthService` | Integrations.swift | Backend auth check |
| `CalendarService` | Integrations.swift | Backend calendar API |
| `MailService` | Integrations.swift | Backend mail API |
| `NutritionService` | Integrations.swift | Meal analysis API |
| `ExportImport` | ExportImport.swift | JSON export/import |

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
| `/analyze-meal` | POST | Nutrition analysis |
| `/llm/plan` | POST | AI task advice |

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
- ✅ Completion trend (bar + line overlay, by period)
- ✅ Productivity by hour of day
- ✅ Category distribution (donut chart)
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

---

## Known Limitations

1. **iCloud KV Store 1MB limit** — all data serialized as JSON; will fail silently with ~200-300 tasks
2. **No data migration** — storage key version bumps abandon old data
3. **No conflict resolution** — last-write-wins on iCloud sync
4. **HTTP backend** — no TLS; requires App Transport Security exception
5. **Localization partial** — L10n infrastructure ready but most views still use hardcoded Russian strings
6. **Calendar/Mail iOS-only** — unavailable on macOS/watchOS

---

## Development Roadmap

### Phase 1 — Stability & Quality (Current)
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

### Phase 2 — Architecture Cleanup
- [x] Split StructuredMainView.swift into focused files
- [x] Migrate from singletons to proper DI via DependencyContainer
- [x] Connect UseCases layer or simplify
- [x] Unify Repository pattern with PlannerStore
- [x] Remove dead code

### Phase 3 — Features
- [ ] CloudKit migration (replaces KV store, removes 1MB limit)
- [x] Deep linking from widget/notifications to specific tasks
- [x] Chart-based analytics (Swift Charts)
- [x] Localization infrastructure (en/ru)
- [x] Projects/sub-tasks
- [ ] Collaborative task sharing

### Phase 4 — Polish
- [ ] Full VoiceOver accessibility audit
- [ ] Dynamic Type support
- [ ] HTTPS backend migration
- [ ] App Store preparation
- [ ] Onboarding flow
