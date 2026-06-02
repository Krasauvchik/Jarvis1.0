# Structured → Jarvis: аудит паритета

> Цель: воспроизвести в Jarvis функциональность и UX-паттерны приложения Structured.
> **Важно (юридически):** копируется *функциональность*, а не код/ассеты/узнаваемый
> визуальный дизайн Structured. Реализация — собственная. Jarvis изначально
> «Structured-inspired», и по охвату уже шире (почта, Telegram, wellness, AI-коуч).
> Статусы проверены по коду на 2026-06-02. См. также [JARVIS_STATUS.md](../JARVIS_STATUS.md).

Легенда: ✅ есть · 🟡 частично · ❌ нет

---

## 1. Экраны

| Экран Structured | Аналог в Jarvis | Статус | Файлы |
|---|---|:--:|---|
| Таймлайн дня (вертикальный) | TimePanelView | ✅ | `Views/TimelineView.swift` |
| Неделя / несколько дней | Multi-Day / Week / Month режимы | ✅ | `Views/TimelineView.swift` |
| Список «Входящие» (unscheduled) | Inbox-секция | ✅ | `StructuredMainView.swift`, `PlannerStore.swift` |
| Карточка задачи (детали) | TaskDetailView / TaskSheets | ✅ | `Views/TaskDetailView.swift`, `Views/TaskSheets.swift` |
| Создание/редактирование задачи | TaskSheets | ✅ | `Views/TaskSheets.swift` |
| Выбор иконки/эмодзи задачи | TaskIcon picker | 🟡 (меньше набор) | `PlannerModels.swift`, `Views/TaskSheetComponents.swift` |
| Настройки | SettingsViews + Settings/* | ✅ | `Views/SettingsViews.swift`, `Views/Settings/*` |
| Кастомизация (темы/акцент/стиль таймлайна) | CustomizationSettingsView | ✅ | `CustomizationManager.swift` |
| Шаблоны / рутины | TaskTemplatesView | ✅ | `Views/TaskTemplatesView.swift` |
| Онбординг | OnboardingView (8 шагов) | ✅ | `Views/OnboardingView.swift` |
| Подписка / Pro (paywall) | SettingsSubscriptionTab | ❌ заглушка (нет StoreKit) | `Views/Settings/SettingsSubscriptionTab.swift` |
| Apple Watch | WatchPlannerView | ✅ | `MainView.swift` |
| Виджеты на домашнем экране | JarvisWidget | 🟡 код есть, target в Xcode | `JarvisWidgetExtension/JarvisWidget.swift` |
| Виджеты на Lock Screen (accessory) | — | ❌ | — |

## 2. Фичи

| Фича Structured | Статус | Где / что доделать |
|---|:--:|---|
| Задача: время, длительность, заметки | ✅ | `PlannerModels.swift` (PlannerTask) |
| Подзадачи / чеклист | ✅ | subtasks в PlannerTask |
| Повторения (RRULE-подобные) | ✅ | `recurrenceRule` |
| All-day / «в любое время» | ✅ | `isAllDay`, inbox |
| Перетаскивание со снапом (15 мин) | ✅ | `Views/TimelineView.swift:360+` |
| Напоминания/уведомления | ✅ | `NotificationManager.swift` (+ запрос в онбординге) |
| Календарь Apple (EventKit) | ✅ | `EventKitService.swift`, `CalendarSyncService.swift` |
| Календарь Google | ✅ | `Views/CalendarView.swift` + backend |
| iCloud-синк | ✅ | `CloudSync.swift`, SwiftData+CloudKit |
| Siri Shortcuts / App Intents | ✅ | `JarvisIntents.swift` |
| Live Activity / Dynamic Island | 🟡 есть менеджер, проверить DI-вёрстку | `LiveActivityManager.swift` |
| Темы / акцентные цвета / стиль таймлайна | ✅ | `CustomizationManager.swift` |
| Сменные иконки приложения | ❌ нет `setAlternateIconName` | добавить |
| Фокус-режим / таймер | ✅ | `Views/FocusTimerView.swift` |
| Привычки, канбан, проекты, теги | ✅ (шире Structured) | соответствующие Views |
| Бэкап / экспорт-импорт | ✅ | `ExportImport.swift` |
| **Structured AI: авто-план дня** | ✅ реализовано (intent `.planDay`, чип «План дня») | `AIManager.handlePlanDay` |
| **Structured AI: разбивка крупной задачи** | ✅ кнопка «Разбить с ИИ» в TaskDetail | `AIManager.breakdownTask`, `Views/TaskDetailView.swift` |
| Подписка/монетизация (StoreKit 2) | ❌ заглушка | реализовать (нужен App Store Connect) |
| Lock Screen / accessory-виджеты | 🟡 вью готовы, нужен target в Xcode | `JarvisWidgetExtension/JarvisWidget.swift` |
| Хаптика при перетаскивании в таймлайне | ✅ тик по слотам + подтверждение | `Views/TimelineView.swift` |

**Итог:** Jarvis уже на ~85% паритета и шире по охвату. Реальные пробелы — ниже.

---

## 3. Бэклог реализации (по приоритетам пользователя)

### P1. Авто-планирование дня ИИ (сигнатурная фича Structured AI)
- **Что у Structured:** кнопка «расставь мои задачи по дню» — ИИ берёт незапланированные
  задачи и раскладывает по свободным слотам с учётом длительности, рабочих часов,
  существующих событий; плюс «разбей большую задачу на подзадачи».
- **Что есть:** `AIManager` (intent-роутер, Gemini/backend), календарный контекст,
  свободные слоты вычислимы из EventKit + задач. Нет самого флоу авто-расстановки.
- **Делаем:**
  1. Новый intent `.planDay` в `AIManager.detectIntent` + handler `handlePlanDay`.
  2. Промпт: вход — список незапланированных задач (title, est. duration, priority),
     рабочие часы (`Config.Defaults.rise/windDown`), занятые слоты (EventKit + задачи дня).
     Выход — JSON `[{taskId, start, durationMinutes}]`.
  3. Применение: `PlannerStore.scheduleFromInbox(...)` для каждого назначения; превью+подтверждение.
  4. «Разбивка задачи»: intent `.breakdownTask` → подзадачи в TaskDetail.
  5. UI: кнопка «Plan my day» в таймлайне/AI-баре; лист предпросмотра расстановки.
- **Файлы:** `AIManager.swift`, `PlannerStore.swift`, `Views/TimelineView.swift` или `AICommandBarOverlay.swift`, `EventKitService.swift` (свободные слоты).

### P2. Lock Screen / accessory-виджеты + домашний виджет
- **Что есть:** `JarvisWidget` (systemSmall/Medium), данные в App Group, reload-триггер.
- **Делаем:**
  1. Завести widget-target в Xcode (шаги в JARVIS_STATUS.md) — разблокирует всё.
  2. Добавить семейства `.accessoryRectangular`, `.accessoryInline`, `.accessoryCircular`
     в `supportedFamilies` + соответствующие вью (следующая задача / счётчик на сегодня).
  3. Локализовать строки виджета через его strings-каталог.
- **Файлы:** `JarvisWidgetExtension/JarvisWidget.swift`, новый `*+Accessory.swift`.

### P3. Кастомизация и paywall (StoreKit 2)
- **Сменные иконки приложения:**
  1. Добавить альтернативные `CFBundleAlternateIcons` в Info.plist + наборы PNG.
  2. UI выбора в CustomizationSettingsView → `UIApplication.shared.setAlternateIconName`.
- **Paywall / подписка (StoreKit 2):**
  1. `StoreManager` (StoreKit 2: `Product`, `Transaction.currentEntitlements`, listener).
  2. Конфиг продуктов (App Store Connect) + локальный `.storekit` для тестов.
  3. Paywall-экран; гейтинг Pro-фич (что считать Pro — согласовать).
  4. Заменить заглушку `SettingsSubscriptionTab` на реальные цены/состояние.
- **Файлы:** новый `StoreManager.swift`, `Views/Settings/SettingsSubscriptionTab.swift`,
  `CustomizationManager.swift`, `Info.plist`, `Assets.xcassets` (иконки).

### P4. Полировка таймлайна / UX
- **Делаем (итеративно, по скринам):**
  - Текущее-время «now»-линия, авто-скролл к текущему часу (проверить/улучшить).
  - Хаптика при снапе перетаскивания (`HapticManager`).
  - Плавная анимация блоков, «призрак» при драге, индикатор пересечения событий.
  - Пустые состояния и микроанимации в духе Structured.
- **Файлы:** `Views/TimelineView.swift`, `HapticManager.swift`, `CustomizationManager.swift`.

---

## 4. Вне скоупа / осторожно
- Не копируем ассеты, тексты, точные цвета и узнаваемый визуал Structured (trade dress/IP).
- Скриншоты Structured от пользователя используем как референс UX, не как источник для копирования пиксель-в-пиксель.

## 5. Порядок
P2 (виджеты — быстрый видимый результат, нужен Xcode-target) → P1 (AI-план дня —
наибольшая ценность) → P4 (полировка) → P3 (paywall, после согласования Pro-фич и
аккаунта App Store Connect).
