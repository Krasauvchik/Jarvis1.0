import SwiftUI
import Combine

// MARK: - Habit Model (inspired by Structured's habit tracker)
// Structured offers daily/weekly habit tracking with streaks and visual progress.

struct Habit: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var icon: String
    var colorIndex: Int
    var frequency: HabitFrequency
    var targetCount: Int          // how many times per period (e.g. 3x/week)
    var completions: [Date]       // dates when habit was completed
    var createdAt: Date
    var isArchived: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "checkmark.circle.fill",
        colorIndex: Int = 3,
        frequency: HabitFrequency = .daily,
        targetCount: Int = 1,
        completions: [Date] = [],
        createdAt: Date = Date(),
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorIndex = colorIndex
        self.frequency = frequency
        self.targetCount = targetCount
        self.completions = completions
        self.createdAt = createdAt
        self.isArchived = isArchived
    }
    
    enum HabitFrequency: String, Codable, CaseIterable {
        case daily, weekly, monthly
        
        var displayName: String {
            switch self {
            case .daily: return L10n.habitDaily
            case .weekly: return L10n.habitWeekly
            case .monthly: return L10n.habitMonthly
            }
        }
    }
    
    // MARK: - Computed
    
    var color: Color {
        JarvisTheme.taskColors[abs(colorIndex) % JarvisTheme.taskColors.count]
    }
    
    func isCompletedToday() -> Bool {
        let cal = Calendar.current
        return completions.contains { cal.isDateInToday($0) }
    }
    
    func completionsInPeriod(_ date: Date = Date()) -> Int {
        let cal = Calendar.current
        switch frequency {
        case .daily:
            return completions.filter { cal.isDate($0, inSameDayAs: date) }.count
        case .weekly:
            let weekOfYear = cal.component(.weekOfYear, from: date)
            let year = cal.component(.yearForWeekOfYear, from: date)
            return completions.filter {
                cal.component(.weekOfYear, from: $0) == weekOfYear &&
                cal.component(.yearForWeekOfYear, from: $0) == year
            }.count
        case .monthly:
            return completions.filter { cal.isDate($0, equalTo: date, toGranularity: .month) }.count
        }
    }
    
    var currentStreak: Int {
        let cal = Calendar.current
        var streak = 0
        var checkDate = Date()
        
        // If not completed today, start from yesterday
        if !isCompletedToday() {
            checkDate = cal.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }
        
        while true {
            let hasCompletion = completions.contains { cal.isDate($0, inSameDayAs: checkDate) }
            if hasCompletion {
                streak += 1
                checkDate = cal.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else {
                break
            }
        }
        return streak
    }
    
    var longestStreak: Int {
        guard !completions.isEmpty else { return 0 }
        let cal = Calendar.current
        let sorted = completions.sorted()
        var maxStreak = 1
        var currentStrk = 1
        
        for i in 1..<sorted.count {
            let prev = cal.startOfDay(for: sorted[i-1])
            let curr = cal.startOfDay(for: sorted[i])
            let diff = cal.dateComponents([.day], from: prev, to: curr).day ?? 0
            if diff == 1 {
                currentStrk += 1
                maxStreak = max(maxStreak, currentStrk)
            } else if diff > 1 {
                currentStrk = 1
            }
        }
        return maxStreak
    }
    
    mutating func toggleToday() {
        let cal = Calendar.current
        if isCompletedToday() {
            completions.removeAll { cal.isDateInToday($0) }
        } else {
            completions.append(Date())
        }
    }
    
    /// Last 7 days completion status (for mini heatmap)
    func last7Days() -> [Bool] {
        let cal = Calendar.current
        return (0..<7).reversed().map { daysAgo in
            let date = cal.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            return completions.contains { cal.isDate($0, inSameDayAs: date) }
        }
    }
}

// MARK: - Habit Store

@MainActor @Observable
final class HabitStore {
    static let shared = HabitStore()
    
    var habits: [Habit] = [] {
        didSet { save() }
    }
    
    private let storageKey = "jarvis_habits_v1"
    
    private init() {
        load()
    }
    
    func addHabit(_ habit: Habit) {
        habits.append(habit)
    }
    
    func updateHabit(_ habit: Habit) {
        if let idx = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[idx] = habit
        }
    }
    
    func deleteHabit(_ id: UUID) {
        habits.removeAll { $0.id == id }
    }
    
    func toggleCompletion(for habitId: UUID) {
        if let idx = habits.firstIndex(where: { $0.id == habitId }) {
            habits[idx].toggleToday()
        }
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(habits) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Habit].self, from: data) else { return }
        habits = decoded
    }
}

// MARK: - Habit Tracker View (inspired by Structured's habit tracker)

struct HabitTrackerView: View {
    let theme: JarvisTheme
    var store = HabitStore.shared
    @State private var showAddHabit = false
    @State private var editingHabit: Habit?
    
    var activeHabits: [Habit] {
        store.habits.filter { !$0.isArchived }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.habitsTitle)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(theme.textPrimary)
                        Text(L10n.habitsSubtitle)
                            .font(.system(size: 14))
                            .foregroundColor(theme.textSecondary)
                    }
                    Spacer()
                    Button(action: { showAddHabit = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(JarvisTheme.accentGreen)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                
                // Today's Progress
                if !activeHabits.isEmpty {
                    todayProgress
                }
                
                // Habit Cards
                if activeHabits.isEmpty {
                    emptyState
                } else {
                    ForEach(activeHabits) { habit in
                        habitCard(habit)
                    }
                }
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $showAddHabit) {
            AddHabitSheet(theme: theme)
        }
        .sheet(item: $editingHabit) { habit in
            AddHabitSheet(theme: theme, editingHabit: habit)
        }
    }
    
    private var todayProgress: some View {
        let completed = activeHabits.filter { $0.isCompletedToday() }.count
        let total = activeHabits.count
        let progress = total > 0 ? Double(completed) / Double(total) : 0
        
        return HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(theme.divider, lineWidth: 6)
                    .frame(width: 56, height: 56)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(JarvisTheme.accentGreen, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                Text("\(completed)/\(total)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(theme.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.habitsTodayProgress)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                Text(progress >= 1.0 ? L10n.habitsAllDone : L10n.habitsKeepGoing)
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
            }
            Spacer()
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(theme.cardBackground))
        .padding(.horizontal)
    }
    
    private func habitCard(_ habit: Habit) -> some View {
        HStack(spacing: 12) {
            // Completion toggle
            Button(action: {
                HapticManager.shared.impact(.light)
                store.toggleCompletion(for: habit.id)
            }) {
                ZStack {
                    Circle()
                        .fill(habit.isCompletedToday() ? habit.color : Color.clear)
                        .frame(width: 36, height: 36)
                    Circle()
                        .stroke(habit.color, lineWidth: 2)
                        .frame(width: 36, height: 36)
                    if habit.isCompletedToday() {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: habit.icon)
                        .font(.system(size: 14))
                        .foregroundColor(habit.color)
                    Text(habit.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.textPrimary)
                        .strikethrough(habit.isCompletedToday(), color: theme.textSecondary)
                }
                
                HStack(spacing: 12) {
                    // Streak
                    Label("\(habit.currentStreak)", systemImage: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                    
                    // Frequency
                    Text(habit.frequency.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(theme.textTertiary)
                    
                    // Mini 7-day heatmap
                    HStack(spacing: 2) {
                        ForEach(Array(habit.last7Days().enumerated()), id: \.offset) { _, done in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(done ? habit.color : theme.divider)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Context menu
            Menu {
                Button(action: { editingHabit = habit }) {
                    Label(L10n.editAction, systemImage: "pencil")
                }
                Button(role: .destructive, action: { store.deleteHabit(habit.id) }) {
                    Label(L10n.delete, systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .foregroundColor(theme.textTertiary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(theme.cardBackground))
        .padding(.horizontal)
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "repeat.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(theme.textTertiary)
            Text(L10n.habitsEmpty)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(theme.textSecondary)
            Text(L10n.habitsEmptyDesc)
                .font(.system(size: 14))
                .foregroundColor(theme.textTertiary)
                .multilineTextAlignment(.center)
            Button(action: { showAddHabit = true }) {
                Text(L10n.habitsAdd)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(JarvisTheme.accentGreen))
            }
            .buttonStyle(.plain)
        }
        .padding(40)
    }
}

// MARK: - Add/Edit Habit Sheet

struct AddHabitSheet: View {
    let theme: JarvisTheme
    var editingHabit: Habit?
    var store = HabitStore.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var icon: String = "checkmark.circle.fill"
    @State private var colorIndex: Int = 3
    @State private var frequency: Habit.HabitFrequency = .daily
    @State private var targetCount: Int = 1
    
    private let icons = ["checkmark.circle.fill", "drop.fill", "figure.run", "book.fill", "brain.head.profile",
                         "heart.fill", "moon.fill", "sun.max.fill", "dumbbell.fill", "fork.knife",
                         "pill.fill", "music.note", "cup.and.saucer.fill", "laptopcomputer", "paintbrush.fill"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.habitName) {
                    TextField(L10n.habitNamePlaceholder, text: $name)
                }
                
                Section(L10n.iconSection) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(icons, id: \.self) { ic in
                            Button(action: { icon = ic }) {
                                Image(systemName: ic)
                                    .font(.system(size: 22))
                                    .foregroundColor(icon == ic ? JarvisTheme.taskColors[colorIndex % JarvisTheme.taskColors.count] : theme.textSecondary)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle().fill(icon == ic ? JarvisTheme.taskColors[colorIndex % JarvisTheme.taskColors.count].opacity(0.15) : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Section(L10n.colorSection) {
                    HStack(spacing: 8) {
                        ForEach(0..<JarvisTheme.taskColors.count, id: \.self) { idx in
                            Circle()
                                .fill(JarvisTheme.taskColors[idx])
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle().stroke(Color.white, lineWidth: colorIndex == idx ? 3 : 0)
                                )
                                .onTapGesture { colorIndex = idx }
                        }
                    }
                }
                
                Section(L10n.habitFrequency) {
                    Picker(L10n.habitFrequency, selection: $frequency) {
                        ForEach(Habit.HabitFrequency.allCases, id: \.self) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Stepper(value: $targetCount, in: 1...10) {
                        Text("\(L10n.habitTarget): \(targetCount)x")
                    }
                }
            }
            .navigationTitle(editingHabit != nil ? L10n.habitEdit : L10n.habitsAdd)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) {
                        if let editing = editingHabit {
                            var updated = editing
                            updated.name = name
                            updated.icon = icon
                            updated.colorIndex = colorIndex
                            updated.frequency = frequency
                            updated.targetCount = targetCount
                            store.updateHabit(updated)
                        } else {
                            let habit = Habit(name: name, icon: icon, colorIndex: colorIndex, frequency: frequency, targetCount: targetCount)
                            store.addHabit(habit)
                        }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let h = editingHabit {
                    name = h.name
                    icon = h.icon
                    colorIndex = h.colorIndex
                    frequency = h.frequency
                    targetCount = h.targetCount
                }
            }
        }
    }
}
