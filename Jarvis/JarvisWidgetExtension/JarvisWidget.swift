import WidgetKit
import SwiftUI

// Виджет читает задачи из App Group. Добавьте target «Widget Extension» в Xcode
// и включите App Group «group.com.jarvis.planner» для основного приложения и виджета.

private let appGroupSuite = "group.com.jarvis.planner"
private let widgetTasksKey = "jarvis_widget_tasks"

private struct WidgetTaskSnapshot: Codable {
    let id: UUID
    let title: String
    let date: Date
    let isCompleted: Bool
    let isAllDay: Bool
    let colorIndex: Int
}

private let widgetColors: [Color] = [
    Color(red: 0.4, green: 0.6, blue: 1.0),
    Color(red: 0.2, green: 0.8, blue: 0.5),
    Color(red: 1.0, green: 0.5, blue: 0.3),
    Color(red: 0.6, green: 0.4, blue: 0.9),
    Color(red: 0.9, green: 0.6, blue: 0.2)
]

// MARK: - Timeline Provider

struct JarvisWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> JarvisWidgetEntry {
        JarvisWidgetEntry(date: Date(), tasks: [], title: "Сегодня")
    }

    func getSnapshot(in context: Context, completion: @escaping (JarvisWidgetEntry) -> Void) {
        let entry = makeEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<JarvisWidgetEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func makeEntry() -> JarvisWidgetEntry {
        let calendar = Calendar.current
        let today = Date()
        let tasks = loadTasks().filter { task in
            !task.isCompleted && calendar.isDate(task.date, inSameDayAs: today)
        }.sorted { $0.date < $1.date }
        return JarvisWidgetEntry(date: today, tasks: tasks, title: "Сегодня")
    }

    private func loadTasks() -> [WidgetTaskSnapshot] {
        guard let store = UserDefaults(suiteName: appGroupSuite),
              let data = store.data(forKey: widgetTasksKey),
              let tasks = try? JSONDecoder().decode([WidgetTaskSnapshot].self, from: data) else {
            return []
        }
        return tasks
    }
}

// MARK: - Entry

struct JarvisWidgetEntry: TimelineEntry {
    let date: Date
    let tasks: [WidgetTaskSnapshot]
    let title: String
}

// MARK: - Widget View

struct JarvisWidgetEntryView: View {
    var entry: JarvisWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            if entry.tasks.isEmpty {
                Text("Нет задач на сегодня")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                ForEach(entry.tasks.prefix(family == .systemMedium ? 5 : 3), id: \.id) { task in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(widgetColors[task.colorIndex % widgetColors.count])
                            .frame(width: 8, height: 8)
                        Text(task.title)
                            .font(.subheadline)
                            .lineLimit(1)
                            .foregroundColor(.primary)
                        Spacer()
                        if !task.isAllDay {
                            Text(task.date, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Widget

struct JarvisWidget: Widget {
    let kind: String = "JarvisWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: JarvisWidgetProvider()) { entry in
            JarvisWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Jarvis")
        .description("Задачи на сегодня")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

// MARK: - Widget Bundle (точка входа расширения)

@main
struct JarvisWidgetBundle: WidgetBundle {
    var body: some Widget {
        JarvisWidget()
    }
}

#Preview(as: .systemSmall) {
    JarvisWidget()
} timeline: {
    JarvisWidgetEntry(date: Date(), tasks: [], title: "Сегодня")
}
