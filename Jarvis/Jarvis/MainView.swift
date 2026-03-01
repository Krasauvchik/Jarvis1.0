import SwiftUI

// MARK: - MainView (watchOS entry point)
// iOS / macOS / iPadOS -> StructuredMainView; watchOS -> MainView

struct MainView: View {
    @StateObject private var store = PlannerStore.shared
    @StateObject private var wellness = WellnessStore()

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    WatchPlannerView(store: store)
                } label: {
                    Label("Plan", systemImage: "checklist")
                }
                NavigationLink {
                    WatchWellnessView(wellness: wellness)
                } label: {
                    Label("Health", systemImage: "heart.text.square")
                }
            }
            .navigationTitle("Jarvis")
        }
    }
}

// MARK: - Watch Planner

struct WatchPlannerView: View {
    @ObservedObject var store: PlannerStore

    var body: some View {
        List {
            Section {
                let todayTasks = store.tasks.filter {
                    Calendar.current.isDateInToday($0.date)
                }
                if todayTasks.isEmpty {
                    Text("No tasks today")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(todayTasks) { task in
                        WatchTaskRow(task: task) {
                            store.toggleCompletion(task: task, onDay: Date())
                        }
                    }
                }
            } header: {
                Text("Today")
            }

            if !store.inboxTasks.isEmpty {
                Section {
                    ForEach(store.inboxTasks.prefix(5)) { task in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(task.taskColor)
                                .frame(width: 8, height: 8)
                            Text(task.title)
                                .lineLimit(1)
                        }
                    }
                } header: {
                    Text("Inbox")
                }
            }
        }
        .navigationTitle("Plan")
    }
}

// MARK: - Watch Task Row

struct WatchTaskRow: View {
    let task: PlannerTask
    let onToggle: () -> Void

    var body: some View {
        Button {
            onToggle()
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(task.taskColor, lineWidth: 2)
                        .frame(width: 20, height: 20)
                    if task.isCompleted {
                        Circle()
                            .fill(task.taskColor)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.system(.body))
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Watch Wellness View

struct WatchWellnessView: View {
    @ObservedObject var wellness: WellnessStore

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "fork.knife")
                        .foregroundStyle(.orange)
                    Text("\(wellness.todayCalories) kcal")
                        .fontWeight(.semibold)
                }
            } header: {
                Text("Today")
            }

            if let lastSleep = wellness.sleep.last {
                Section {
                    HStack {
                        Image(systemName: "moon.zzz.fill")
                            .foregroundStyle(.indigo)
                        Text(String(format: "%.1f h", lastSleep.hours))
                            .fontWeight(.semibold)
                    }
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(.cyan)
                        let startStr = lastSleep.start.formatted(date: .omitted, time: .shortened)
                        let endStr = lastSleep.end.formatted(date: .omitted, time: .shortened)
                        Text("\(startStr) – \(endStr)")
                    }
                } header: {
                    Text("Sleep")
                }
            }

            Section {
                let todayActivity = wellness.activities.filter {
                    Calendar.current.isDateInToday($0.date)
                }
                let totalMinutes = todayActivity.reduce(0) { $0 + $1.minutes }
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(totalMinutes) min")
                        .fontWeight(.semibold)
                }
            } header: {
                Text("Activity")
            }
        }
        .navigationTitle("Health")
    }
}
