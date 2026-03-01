# Jarvis - Архитектура и Заметки

## Обзор проекта

**Jarvis** — планировщик задач для всех устройств Apple (iPhone, iPad, Mac, Apple Watch) с современным UI, синхронизацией через iCloud и поддержкой тем.

---

## Правило UI: три колонки

**Визуально всегда должны оставаться 3 колонки** (как на эталонном скрине):
- Левая: навигация (папки)
- Средняя: список задач
- Правая: календарь и детали дня

**На iPad/Mac:**
- Ширину левой и средней колонок можно менять перетаскиванием разделителя (левая: 160–400 pt, средняя: 240–500 pt). Значения сохраняются между запусками (`jarvis_sidebar_width`, `jarvis_tasklist_width`).
- Левую панель можно скрыть кнопкой в заголовке сайдбара; снова показать — кнопкой «полоска» у левого края экрана (`jarvis_sidebar_hidden`).

Менять **расположение** колонок (порядок слева направо) или убирать среднюю/правую колонки **нельзя** без явного согласования с владельцем проекта.

---

## Структура файлов

```
Jarvis/
├── JarvisApp.swift              # Точка входа приложения
├── Jarvis/
│   ├── StructuredMainView.swift # Главный UI (3-колоночный layout)
│   ├── PlannerModels.swift      # Модели данных (PlannerTask, PlannerStore)
│   ├── JarvisTheme.swift        # Система тем (светлая/тёмная)
│   ├── Config.swift             # Конфигурация (URL, ключи)
│   ├── CloudSync.swift          # Синхронизация iCloud (NSUbiquitousKeyValueStore)
│   ├── NotificationManager.swift # Уведомления и напоминания
│   ├── AIManager.swift          # Интеграция с AI (планирование)
│   ├── SpeechRecognizer.swift   # Голосовой ввод
│   └── ...
└── Info.plist
```

---

## Ключевые компоненты

### 1. StructuredMainView.swift

Главный View приложения с адаптивным layout:

#### Layouts:
- **iPhone (compact)**: TabView с 4 вкладками (Сегодня, Inbox, Выполнено, Настройки)
- **iPad/Mac**: Трёхколоночный layout (Навигация | Список задач | Timeline)
- **watchOS**: Упрощённый список задач

#### Навигация (левая панель):
```swift
enum NavigationSection: String, CaseIterable {
    case inbox = "Inbox"
    case today = "Сегодня"
    case scheduled = "Запланир."
    case futurePlans = "Планы на будущее"
    case completed = "Выполнено"
    case all = "Все задачи"
}
```

#### Компоненты:
- `navigationSidebar(onHide:)` — левая панель с меню и статистикой; кнопка скрытия панели в шапке
- `ColumnResizer` — перетаскиваемый разделитель между колонками (меняет ширину левой или средней колонки)
- `taskListPanel` — средняя панель со списком задач
- `timelinePanel` — правая панель с календарём и timeline
- `taskContextMenu` — контекстное меню задачи

---

### 2. PlannerModels.swift

#### PlannerTask
```swift
struct PlannerTask: Identifiable, Codable {
    let id: UUID
    var title: String
    var notes: String
    var date: Date
    var durationMinutes: Int
    var isAllDay: Bool
    var recurrenceRule: RecurrenceRule?
    var isCompleted: Bool
    var hasAlarm: Bool
    var isInbox: Bool
    var colorIndex: Int          // 0-7 цветов
    var icon: String             // SF Symbol
}
```

#### TaskIcon
```swift
enum TaskIcon: String, CaseIterable {
    case star, heart, bolt, flame, flag, bell...
    // 40+ иконок
}
```

#### PlannerStore
Singleton с CRUD операциями и iCloud синхронизацией:
```swift
@MainActor
final class PlannerStore: ObservableObject {
    static let shared = PlannerStore()
    @Published var tasks: [PlannerTask]
    
    func add(_ task: PlannerTask)
    func update(_ task: PlannerTask)
    func delete(_ task: PlannerTask)
    func removeCompleted()
    func removeAll()
    func tasksForDay(_ day: Date) -> [PlannerTask]
}
```

---

### 3. JarvisTheme.swift

#### ThemeMode
```swift
enum ThemeMode: String, CaseIterable {
    case light, dark, system
}
```

#### ThemeManager
```swift
@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    @Published var currentTheme: ThemeMode
}
```

#### JarvisTheme
Структура с адаптивными цветами:
```swift
struct JarvisTheme {
    let isDark: Bool
    
    // Фоны
    var background: Color
    var cardBackground: Color
    var sidebarBackground: Color
    var inboxBackground: Color
    
    // Текст
    var textPrimary: Color
    var textSecondary: Color
    var textTertiary: Color
    
    // Статические акценты
    static let accent: Color       // Коралловый
    static let accentGreen: Color
    static let accentBlue: Color
    static let accentOrange: Color
    static let accentPurple: Color
    
    // 8 цветов задач
    static let taskColors: [Color]
}
```

---

### 4. CloudSync.swift

Синхронизация через `NSUbiquitousKeyValueStore` (без CloudKit):
```swift
@MainActor
final class CloudSync: ObservableObject {
    static let shared = CloudSync()
    private let kvStore = NSUbiquitousKeyValueStore.default
    
    func saveTasks(_ tasks: [PlannerTask])
    func loadTasks() -> [PlannerTask]?
    func saveDayBounds(_ bounds: DayBounds)
    func loadDayBounds() -> DayBounds?
}
```

---

### 5. SleepCalculator (Калькулятор сна)

Функционал на основе [Лайфхакера](https://lifehacker.ru/special/sleepycalc/):

```swift
@MainActor
final class SleepCalculator: ObservableObject {
    @Published var wakeUpTime: Date
    @Published var bedTime: Date
    @Published var mode: CalculationMode  // wakeUp / bedTime
    
    // Один цикл сна = 90 минут
    // Время засыпания = 14 минут
    
    var recommendedWakeUpTimes: [Date]  // 4-6 циклов
    var recommendedBedTimes: [Date]     // 4-6 циклов
}
```

---

### 6. UserProfile

```swift
@MainActor
final class UserProfile: ObservableObject {
    static let shared = UserProfile()
    
    @Published var name: String
    @Published var email: String
    @Published var avatarEmoji: String
    
    var initials: String  // "US" из "User Smith"
}
```

---

## Функционал

### Управление задачами
- ✅ Создание задачи (название, заметки, дата, длительность)
- ✅ Inbox — задачи без времени для планирования
- ✅ Выполнение задачи (чекбокс, свайп)
- ✅ Редактирование (тап или контекстное меню)
- ✅ Удаление (свайп влево, контекстное меню)
- ✅ Дублирование задачи
- ✅ Перенос на завтра
- ✅ Смена цвета (8 цветов)
- ✅ Смена иконки (40+ иконок)
- ✅ Повторяющиеся задачи (RecurrenceRule)

### Навигация
- ✅ Inbox — незапланированные задачи
- ✅ Сегодня — задачи на текущий день
- ✅ Запланированные — все задачи с датой
- ✅ Выполненные — история завершённых
- ✅ Все задачи — полный список

### Drag & Drop
- ✅ Перетаскивание задачи на день в календаре
- ✅ Перетаскивание в Inbox
- ✅ Визуальный feedback при перетаскивании

### Темы
- ✅ Светлая тема
- ✅ Тёмная тема
- ✅ Системная (следует iOS/macOS)
- ✅ Мгновенное переключение
- ✅ Сохранение в UserDefaults

### Калькулятор сна
- ✅ Режим "Когда проснуться" → рекомендуемое время засыпания
- ✅ Режим "Когда лечь спать" → рекомендуемое время пробуждения
- ✅ 4-6 циклов сна (6-9 часов)
- ✅ Учёт 14 минут на засыпание
- ✅ Пометка "Оптимально" для 6 циклов

### Профиль пользователя
- ✅ Имя и email
- ✅ Аватар (эмодзи)
- ✅ Статистика (всего, выполнено, % успеха)
- ✅ Сохранение в UserDefaults

### Синхронизация
- ✅ iCloud через NSUbiquitousKeyValueStore
- ✅ Автоматическая синхронизация при изменениях
- ✅ Offline-first (локальное сохранение + синхронизация)

---

## UI/UX особенности

### Цветовая схема задач
Названия задач в средней панели отображаются **цветом задачи** (не белым), что соответствует оригинальному дизайну.

### Контекстное меню задачи (долгое нажатие / правый клик)
- Редактировать
- Выполнить / Отменить
- Дублировать
- В Inbox
- На завтра
- Цвет (подменю с 8 цветами)
- Удалить

### Свайпы (iPhone)
- Свайп влево → Удалить
- Свайп вправо → Выполнить / Запланировать

### Адаптивность
- iPhone: TabView (compact)
- iPad: 3 колонки (regular)
- Mac: 3 колонки + тулбар
- Apple Watch: простой список

---

## Известные проблемы и решения

### 1. Freeze на iPhone при запуске
**Причина**: CloudKit container не настроен в Apple Developer Portal.
**Решение**: Убран CloudKit, используется только NSUbiquitousKeyValueStore.

### 2. Info.plist конфликт
**Причина**: Дублирование Info.plist в build phases.
**Решение**: Info.plist перемещён в корень проекта, пути обновлены в project.pbxproj.

### 3. Swift 6 concurrency warnings
**Причина**: Доступ к MainActor-isolated свойствам из nonisolated контекста.
**Решение**: Добавлены `@MainActor`, `nonisolated`, `Sendable` где необходимо.

### 4. .datePickerStyle(.wheel) на macOS
**Причина**: .wheel стиль не доступен на macOS.
**Решение**: Условная компиляция `#if os(iOS)`.

---

## Технологии

- **SwiftUI** — UI framework
- **Combine** — реактивное программирование
- **NSUbiquitousKeyValueStore** — iCloud Key-Value синхронизация
- **UserDefaults** — локальное хранение
- **SF Symbols** — иконки
- **UniformTypeIdentifiers** — Drag & Drop

---

## Планы на будущее

- [x] **Виджеты (WidgetKit)** — виджет «Задачи на сегодня» в `JarvisWidgetExtension/`. Добавьте target Widget Extension в Xcode и App Group `group.com.jarvis.planner`.
- [x] **Напоминания через Siri** — App Intents: «Добавить задачу в Jarvis», «Показать задачи на сегодня» (`JarvisIntents.swift`).
- [x] **Интеграция с календарём iOS** — EventKit: синхронизация задач с приложением «Календарь» (`CalendarSyncService.swift`, настройки → Календарь).
- [x] **Экспорт/импорт данных** — JSON-бэкап в настройках → Данные (`ExportImport.swift`).
- [x] **Категории задач** — модели и UI в добавлении/редактировании задачи, управление в настройках → Категории и теги.
- [x] **Теги** — множественный выбор тегов у задачи, управление в настройках.
- [x] **Поиск по задачам** — поле поиска над списком задач (трёхколоночный layout).

---

## Контакты

Проект разработан с помощью AI-ассистента Claude (Anthropic).

Дата создания: Март 2026
