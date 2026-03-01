# Jarvis Planner

Мультиплатформенное приложение для планирования задач с iCloud синхронизацией между всеми устройствами Apple.

## Платформы

- **iOS 17+** — полный функционал
- **iPadOS 17+** — полный функционал
- **macOS 14+** — планировщик, аналитика, настройки
- **watchOS 10+** — просмотр и выполнение задач, здоровье

## Синхронизация

Все данные автоматически синхронизируются между устройствами через **iCloud**:
- Задачи и Inbox
- Настройки дня (Rise & Wind Down)
- Данные о здоровье (питание, сон, активность)
- Выбранная модель ИИ

Изменения на одном устройстве мгновенно отображаются на всех остальных.

## Структура проекта

```
├── Jarvis/              # SwiftUI приложение (все платформы)
│   └── Jarvis/
│       ├── CloudSync.swift       # iCloud синхронизация
│       ├── PlannerModels.swift   # Модели данных
│       ├── PlannerView.swift     # Главный экран планировщика
│       ├── MainView.swift        # Навигация по вкладкам
│       └── Views/                # Дополнительные экраны
├── jarvis-backend/      # Python бэкенд (FastAPI)
└── docs/                # Документация проекта
```

## Быстрый старт

### Backend

```bash
cd jarvis-backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```

### Приложение

1. Откройте `Jarvis/Jarvis.xcodeproj` в Xcode 15+
2. Выберите целевую платформу (iOS, macOS, watchOS)
3. Убедитесь, что включены iCloud capabilities:
   - iCloud → Key-value storage
   - iCloud → CloudKit (контейнер: `iCloud.com.jarvis.planner`)
4. Запустите на симуляторе или устройстве

## Функционал

| Функция | iOS/iPadOS | macOS | watchOS |
|---------|------------|-------|---------|
| Таймлайн задач | ✅ | ✅ | ✅ (упрощённый) |
| Inbox | ✅ | ✅ | ✅ |
| Drag & Drop | ✅ | ✅ | — |
| Календарь Google | ✅ | — | — |
| Почта Gmail | ✅ | — | — |
| Аналитика | ✅ | ✅ | — |
| Здоровье | ✅ | ✅ | ✅ |
| Напоминания | ✅ | ✅ | ✅ |
| iCloud Sync | ✅ | ✅ | ✅ |

## Бэкенд API

| Метод | Путь | Описание |
|-------|------|----------|
| GET | /health | Проверка работоспособности |
| GET | /calendar/events | События календаря |
| POST | /analyze-meal | Анализ фото блюда |
| POST | /llm/plan | Советы по задачам |

## Конфигурация

- Бэкенд URL: `Config.swift` → `backendURL`
- iCloud контейнер: `Config.swift` → `iCloudContainerID`

## Оптимизации

- `LazyVStack` / `LazyHStack` для списков
- `@MainActor` для thread-safe UI обновлений
- `Sendable` для безопасной передачи между потоками
- Кэширование данных в `NSUbiquitousKeyValueStore`
- Минимизация перерисовок через `@ViewBuilder`

## Требования

- iOS 17+ / iPadOS 17+ / macOS 14+ / watchOS 10+
- Python 3.11+ (для бэкенда)
- Xcode 15+
- Apple ID с iCloud
