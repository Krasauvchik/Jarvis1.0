#if !os(watchOS)
import SwiftUI
import Charts

// MARK: - Chart Analytics View (Phase 3: Swift Charts)

@available(iOS 16.0, macOS 13.0, *)
struct ChartAnalyticsView: View {
    @StateObject private var store = PlannerStore.shared
    @ObservedObject var aiManager: AIManager
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(Config.Storage.skillDeepAnalysisKey) private var skillDeepAnalysis = true
    
    @State private var selectedPeriod: AnalyticsPeriod = .week
    @State private var llmAdvice: String?
    @State private var isLoadingAdvice = false
    
    private var theme: JarvisTheme {
        JarvisTheme.current(for: colorScheme)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    periodPicker
                    
                    summaryCards
                    
                    completionTrendChart
                    
                    productivityByHourChart
                    
                    categoryDistributionChart
                    
                    priorityBreakdownChart
                    
                    streakSection
                    
                    if skillDeepAnalysis {
                        aiAdviceSection
                    }
                }
                .padding()
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle(L10n.analyticsTitle)
        }
    }
    
    // MARK: - Period Picker
    
    private var periodPicker: some View {
        Picker(L10n.periodLabel, selection: $selectedPeriod) {
            ForEach(AnalyticsPeriod.allCases) { period in
                Text(period.title).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel(L10n.periodLabel)
        .accessibilityHint(L10n.periodPickerHint)
    }
    
    // MARK: - Summary Cards
    
    private var summaryCards: some View {
        let data = periodData
        let total = data.map(\.total).reduce(0, +)
        let completed = data.map(\.completed).reduce(0, +)
        let rate = total > 0 ? Double(completed) / Double(total) : 0
        let avgPerDay = data.isEmpty ? 0.0 : Double(total) / Double(data.count)
        
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                summaryCard(
                    title: L10n.total,
                    value: "\(total)",
                    icon: "list.bullet.clipboard",
                    color: JarvisTheme.accentBlue
                )
                summaryCard(
                    title: L10n.completed,
                    value: "\(completed)",
                    icon: "checkmark.circle.fill",
                    color: JarvisTheme.accentGreen,
                    subtitle: "\(Int(rate * 100))%"
                )
                summaryCard(
                    title: L10n.avgPerDay,
                    value: String(format: "%.1f", avgPerDay),
                    icon: "chart.bar.fill",
                    color: JarvisTheme.accent
                )
                summaryCard(
                    title: L10n.streakDays,
                    value: "\(currentStreak)",
                    icon: "flame.fill",
                    color: JarvisTheme.accentOrange
                )
            }
        }
    }
    
    private func summaryCard(title: String, value: String, icon: String, color: Color, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Spacer()
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(color)
                }
            }
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(theme.textPrimary)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(theme.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(16)
        .frame(minWidth: 120, idealWidth: 140)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.cardBackground)
                .shadow(color: theme.cardShadow, radius: 4, y: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)\(subtitle.map { ", \($0)" } ?? "")")
    }
    
    // MARK: - Completion Trend Chart
    
    private var completionTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.completionTrend)
                .font(.headline.weight(.semibold))
                .foregroundStyle(theme.textPrimary)
            
            let data = periodData
            if data.isEmpty {
                noDataPlaceholder
            } else {
                Chart {
                    ForEach(data) { day in
                        BarMark(
                            x: .value(L10n.dateLabel, day.date, unit: .day),
                            y: .value(L10n.total, day.total)
                        )
                        .foregroundStyle(JarvisTheme.accentBlue.opacity(0.4))
                        
                        BarMark(
                            x: .value(L10n.dateLabel, day.date, unit: .day),
                            y: .value(L10n.completed, day.completed)
                        )
                        .foregroundStyle(JarvisTheme.accentGreen)
                    }
                }
                .chartYAxisLabel(L10n.tasksLabel)
                .frame(height: 220)
            }
        }
        .jarvisSectionCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.completionTrend)
    }
    
    // MARK: - Productivity by Hour Chart
    
    private var productivityByHourChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.productivityByHour)
                .font(.headline.weight(.semibold))
                .foregroundStyle(theme.textPrimary)
            
            let hourData = productivityByHour
            if hourData.isEmpty {
                noDataPlaceholder
            } else {
                Chart(hourData) { item in
                    BarMark(
                        x: .value(L10n.hourLabel, "\(item.hour):00"),
                        y: .value(L10n.countLabel, item.count)
                    )
                    .foregroundStyle(JarvisTheme.accent)
                }
                .chartYAxisLabel(L10n.completed)
                .frame(height: 200)
            }
        }
        .jarvisSectionCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.productivityByHour)
    }
    
    // MARK: - Category Distribution Chart
    
    private var categoryDistributionChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.taskCategories)
                .font(.headline.weight(.semibold))
                .foregroundStyle(theme.textPrimary)
            
            let catData = categoryBreakdown.filter { $0.count > 0 }
            if catData.isEmpty {
                noDataPlaceholder
            } else {
                // Horizontal bar chart instead of SectorMark (more stable on macOS)
                Chart(catData) { item in
                    BarMark(
                        x: .value(L10n.countLabel, item.count),
                        y: .value(L10n.categoryLabel, item.name)
                    )
                    .foregroundStyle(item.color)
                    .annotation(position: .trailing) {
                        Text("\(item.count)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(theme.textSecondary)
                    }
                }
                .frame(height: max(120, CGFloat(catData.count) * 40))
                
                // Legend
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(catData) { item in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(item.color)
                                .frame(width: 10, height: 10)
                            Text(item.name)
                                .font(.system(size: 12))
                                .foregroundColor(theme.textSecondary)
                                .lineLimit(1)
                            Spacer()
                            Text("\(item.count)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(theme.textPrimary)
                        }
                    }
                }
            }
        }
        .jarvisSectionCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.taskCategories)
    }
    
    // MARK: - Priority Breakdown Chart
    
    private var priorityBreakdownChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.byPriority)
                .font(.headline.weight(.semibold))
                .foregroundStyle(theme.textPrimary)
            
            let prioData = priorityData
            if prioData.allSatisfy({ $0.count == 0 }) {
                noDataPlaceholder
            } else {
                Chart(prioData) { item in
                    BarMark(
                        x: .value(L10n.priorityLabel, item.name),
                        y: .value(L10n.countLabel, item.count)
                    )
                    .foregroundStyle(item.color)
                    .annotation(position: .top) {
                        if item.count > 0 {
                            Text("\(item.count)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(item.color)
                        }
                    }
                }
                .frame(height: 160)
            }
        }
        .jarvisSectionCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.byPriority)
    }
    
    // MARK: - Streak Section
    
    private var streakSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundColor(JarvisTheme.accentOrange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.productivityStreak)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                    
                    Text(streakDescription)
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }
                
                Spacer()
                
                Text("\(currentStreak)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(JarvisTheme.accentOrange)
            }
            
            // Last 14 days streak dots
            HStack(spacing: 4) {
                ForEach(streakDots, id: \.date) { dot in
                    VStack(spacing: 2) {
                        Circle()
                            .fill(dot.hasCompleted ? JarvisTheme.accentGreen : theme.divider)
                            .frame(width: 16, height: 16)
                            .overlay {
                                if dot.hasCompleted {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        
                        Text(dot.label)
                            .font(.system(size: 8))
                            .foregroundColor(
                                Calendar.current.isDateInToday(dot.date) ?
                                JarvisTheme.accent : theme.textTertiary
                            )
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .jarvisSectionCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(L10n.productivityStreak): \(currentStreak) \(L10n.streakDaysLabel). \(streakDescription)")
    }
    
    // MARK: - AI Advice
    
    private var aiAdviceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.aiAnalysis)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                
                if isLoadingAdvice {
                    ProgressView()
                } else {
                    Button(L10n.refresh) {
                        Task { await requestLLMAdvice() }
                    }
                    .buttonStyle(ChipButtonStyle())
                    .bounceOnTap()
                    .disabled(store.tasks.isEmpty)
                }
            }
            
            Text(llmAdvice ?? smartSuggestion)
                .font(.subheadline)
                .foregroundStyle(llmAdvice == nil ? theme.textSecondary : theme.textPrimary)
        }
        .jarvisSectionCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(L10n.aiAnalysis): \(llmAdvice ?? smartSuggestion)")
    }
    
    // MARK: - No Data Placeholder
    
    private var noDataPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 32))
                .foregroundColor(theme.textTertiary)
            Text(L10n.noDataPeriod)
                .font(.subheadline)
                .foregroundColor(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .accessibilityLabel(L10n.noDataPeriod)
    }
    
    // MARK: - Data Calculations
    
    private var periodData: [DayAnalytics] {
        let calendar = Calendar.current
        let now = Date()
        let daysBack: Int
        
        switch selectedPeriod {
        case .week: daysBack = 7
        case .month: daysBack = 30
        case .quarter: daysBack = 90
        }
        
        guard let startDate = calendar.date(byAdding: .day, value: -daysBack + 1, to: now) else { return [] }
        let startOfStart = calendar.startOfDay(for: startDate)
        
        var result: [DayAnalytics] = []
        for offset in 0..<daysBack {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfStart) else { continue }
            let dayTasks = store.tasks.filter {
                !$0.isInbox && calendar.isDate($0.date, inSameDayAs: day)
            }
            let total = dayTasks.count
            let completed = dayTasks.filter(\.isCompleted).count
            result.append(DayAnalytics(date: day, total: total, completed: completed))
        }
        return result
    }
    
    private var productivityByHour: [HourProductivity] {
        let calendar = Calendar.current
        let periodTasks = tasksInPeriod.filter { $0.isCompleted && !$0.isAllDay }
        
        var hourCounts: [Int: Int] = [:]
        for task in periodTasks {
            let hour = calendar.component(.hour, from: task.date)
            hourCounts[hour, default: 0] += 1
        }
        
        guard !hourCounts.isEmpty else { return [] }
        
        let rawMin = hourCounts.keys.min() ?? 6
        let rawMax = hourCounts.keys.max() ?? 22
        let minHour = min(rawMin, rawMax)
        let maxHour = max(rawMin, rawMax)
        
        guard minHour <= maxHour else { return [] }
        
        return (minHour...maxHour).map { hour in
            HourProductivity(hour: hour, count: hourCounts[hour] ?? 0)
        }
    }
    
    private var categoryBreakdown: [CategoryData] {
        let periodTasks = tasksInPeriod
        let categories = store.categories
        
        var catCounts: [UUID?: Int] = [:]
        for task in periodTasks {
            catCounts[task.categoryId, default: 0] += 1
        }
        
        var result: [CategoryData] = []
        for (catId, count) in catCounts.sorted(by: { $0.value > $1.value }) {
            if let catId, let category = categories.first(where: { $0.id == catId }) {
                result.append(CategoryData(
                    name: category.name,
                    count: count,
                    color: category.color
                ))
            } else {
                result.append(CategoryData(
                    name: L10n.noCategory,
                    count: count,
                    color: JarvisTheme.textSecondary
                ))
            }
        }
        return result
    }
    
    private var priorityData: [PriorityData] {
        let periodTasks = tasksInPeriod
        return [
            PriorityData(
                name: L10n.priorityHigh,
                priority: .high,
                count: periodTasks.filter { $0.priority == .high }.count,
                color: .red
            ),
            PriorityData(
                name: L10n.priorityMedium,
                priority: .medium,
                count: periodTasks.filter { $0.priority == .medium }.count,
                color: JarvisTheme.accentOrange
            ),
            PriorityData(
                name: L10n.priorityLow,
                priority: .low,
                count: periodTasks.filter { $0.priority == .low }.count,
                color: JarvisTheme.accentGreen
            ),
        ]
    }
    
    private var tasksInPeriod: [PlannerTask] {
        let calendar = Calendar.current
        let now = Date()
        let daysBack: Int
        switch selectedPeriod {
        case .week: daysBack = 7
        case .month: daysBack = 30
        case .quarter: daysBack = 90
        }
        guard let startDate = calendar.date(byAdding: .day, value: -daysBack + 1, to: now) else { return [] }
        let startOfStart = calendar.startOfDay(for: startDate)
        return store.tasks.filter { $0.date >= startOfStart && !$0.isInbox }
    }
    
    private var currentStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = Date()
        
        while true {
            let dayTasks = store.tasks.filter {
                !$0.isInbox && calendar.isDate($0.date, inSameDayAs: checkDate)
            }
            // A "productive day" = at least 1 task completed that day
            let hasCompleted = dayTasks.contains(where: \.isCompleted)
            if !hasCompleted && !calendar.isDateInToday(checkDate) {
                break
            }
            if hasCompleted {
                streak += 1
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previous
            if streak > 365 { break } // safety cap
        }
        return streak
    }
    
    private var streakDescription: String {
        switch currentStreak {
        case 0: return "Начни серию — выполни хотя бы одну задачу сегодня!"
        case 1...3: return "Хорошее начало! Продолжай."
        case 4...7: return "Отличная неделя! Так держать."
        case 8...14: return "Впечатляющая серия!"
        case 15...30: return "Потрясающая продуктивность!"
        default: return "Ты — машина! 🔥"
        }
    }
    
    private var streakDots: [StreakDot] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "dd"
        
        return (0..<14).reversed().compactMap { offset -> StreakDot? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            let hasCompleted = store.tasks.contains {
                !$0.isInbox && $0.isCompleted && calendar.isDate($0.date, inSameDayAs: day)
            }
            return StreakDot(
                date: day,
                hasCompleted: hasCompleted,
                label: formatter.string(from: day)
            )
        }
    }
    
    private var smartSuggestion: String {
        guard !store.tasks.isEmpty else { return "Пока нет задач. Добавь первую цель на день." }
        
        let completed = store.tasks.lazy.filter(\.isCompleted).count
        let total = store.tasks.count
        let ratio = Double(completed) / Double(total)
        
        let hourData = productivityByHour
        let peakHour = hourData.max(by: { $0.count < $1.count })
        let peakHourText = peakHour.map { "Пик продуктивности — в \($0.hour):00." } ?? ""
        
        switch ratio {
        case 0.8...: return "Отличный баланс! \(peakHourText) Продолжай в том же духе."
        case 0.5..<0.8: return "Хороший темп. \(peakHourText) Попробуй дробить задачи на подзадачи."
        case 0.2..<0.5: return "Много незавершённого. Расставь приоритеты — начни с высоких. \(peakHourText)"
        default: return "Мало завершённых задач. Начни с мелких — они создают инерцию. \(peakHourText)"
        }
    }
    
    private func requestLLMAdvice() async {
        guard !store.tasks.isEmpty else { return }
        isLoadingAdvice = true
        defer { isLoadingAdvice = false }
        
        if let text = await aiManager.generateLLMAdvice(from: store.tasks) {
            await MainActor.run { llmAdvice = text }
        }
    }
}

// MARK: - Analytics Period

enum AnalyticsPeriod: String, CaseIterable, Identifiable {
    case week = "week"
    case month = "month"
    case quarter = "quarter"
    
    var id: String { rawValue }
    var title: String {
        switch self {
        case .week: return L10n.periodWeek
        case .month: return L10n.periodMonth
        case .quarter: return L10n.periodQuarter
        }
    }
}

// MARK: - Analytics Data Models

struct DayAnalytics: Identifiable {
    let id = UUID()
    let date: Date
    let total: Int
    let completed: Int
}

struct HourProductivity: Identifiable {
    var id: Int { hour }
    let hour: Int
    let count: Int
}

struct CategoryData: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
    let color: Color
}

struct PriorityData: Identifiable {
    var id: String { name }
    let name: String
    let priority: TaskPriority
    let count: Int
    let color: Color
}

struct StreakDot {
    let date: Date
    let hasCompleted: Bool
    let label: String
}

#endif
