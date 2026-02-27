import SwiftUI

struct AnalyticsView: View {
    let tasks: [PlannerTask]
    @ObservedObject var aiManager: AIManager
    
    @State private var llmAdvice: String?
    @State private var isLoading = false
    
    private var tasksPerDay: [(date: Date, total: Int, completed: Int)] {
        Dictionary(grouping: tasks) { Calendar.current.startOfDay(for: $0.date) }
            .map { (date: $0.key, total: $0.value.count, completed: $0.value.filter(\.isCompleted).count) }
            .sorted { $0.date < $1.date }
    }
    
    private var suggestionText: String {
        guard !tasks.isEmpty else { return "Пока нет задач. Добавь первую цель на день." }
        
        let ratio = Double(tasks.filter(\.isCompleted).count) / Double(tasks.count)
        switch ratio {
        case 0.8...: return "Отличный баланс! Продолжай в том же духе."
        case 0.4..<0.8: return "Хороший темп. Попробуй дробить задачи на подзадачи."
        default: return "Много незавершённого. Расставь приоритеты."
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statsSection
                    adviceSection
                    llmSection
                }
                .padding()
            }
            .background(JarvisTheme.background.ignoresSafeArea())
            .navigationTitle("Аналитика")
        }
    }
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Статистика")
                .font(.title2.weight(.bold))
                .foregroundColor(JarvisTheme.textPrimary)
            
            if tasksPerDay.isEmpty {
                Text("Нет данных для анализа")
                    .font(.subheadline)
                    .foregroundColor(JarvisTheme.textSecondary)
            } else {
                ForEach(tasksPerDay, id: \.date) { day in
                    HStack {
                        Text(day.date.formatted(date: .abbreviated, time: .omitted))
                        Spacer()
                        Text("Всего: \(day.total)")
                            .foregroundColor(JarvisTheme.textSecondary)
                        Text("\(day.completed) выполнено")
                            .fontWeight(.medium)
                            .foregroundColor(JarvisTheme.accent)
                    }
                    .font(.subheadline)
                }
            }
        }
        .jarvisSectionCard()
    }
    
    private var adviceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Совет")
                .font(.headline.weight(.semibold))
                .foregroundColor(JarvisTheme.textPrimary)
            Text(suggestionText)
                .font(.subheadline)
                .foregroundColor(JarvisTheme.textPrimary)
        }
        .jarvisSectionCard()
    }
    
    private var llmSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Глубокий анализ")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(JarvisTheme.textPrimary)
                Spacer()
                
                if isLoading {
                    ProgressView()
                } else {
                    Button("Обновить") {
                        Task { await requestLLM() }
                    }
                    .buttonStyle(ChipButtonStyle())
                    .disabled(tasks.isEmpty)
                }
            }
            
            Text(llmAdvice ?? "Нажми «Обновить» для получения рекомендаций от AI")
                .font(.subheadline)
                .foregroundColor(llmAdvice == nil ? JarvisTheme.textSecondary : JarvisTheme.textPrimary)
        }
        .jarvisSectionCard()
    }
    
    private func requestLLM() async {
        guard !tasks.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        
        if let text = await aiManager.generateLLMAdvice(from: tasks) {
            llmAdvice = text
        }
    }
}
