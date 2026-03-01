import SwiftUI

/// Task statistics and progress visualization (inspired by Task-Sync-Pro)
struct TaskStatisticsView: View {
    @Environment(\.dependencies) private var dependencies
    @StateObject private var store = PlannerStore.shared
    @StateObject private var network = NetworkMonitor.shared
    @Environment(\.colorScheme) private var colorScheme
    
    private var theme: JarvisTheme {
        JarvisTheme.current(for: colorScheme)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Sync status bar
            syncStatusBar
                .animateOnAppear(delay: 0)
            
            // Statistics cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    statCard(
                        title: "Всего",
                        value: "\(store.tasks.count)",
                        icon: "list.bullet.clipboard",
                        color: JarvisTheme.accentBlue
                    )
                    .animateOnAppear(delay: 0.05)
                    
                    statCard(
                        title: "Выполнено",
                        value: "\(completedCount)",
                        icon: "checkmark.circle.fill",
                        color: JarvisTheme.accentGreen,
                        progress: completionRate
                    )
                    .animateOnAppear(delay: 0.1)
                    
                    statCard(
                        title: "Сегодня",
                        value: "\(todayCount)",
                        icon: "calendar.badge.clock",
                        color: JarvisTheme.accent
                    )
                    .animateOnAppear(delay: 0.15)
                    
                    statCard(
                        title: "Inbox",
                        value: "\(inboxCount)",
                        icon: "tray.fill",
                        color: JarvisTheme.accentOrange
                    )
                    .animateOnAppear(delay: 0.2)
                }
                .padding(.horizontal, 16)
            }
            
            // Weekly progress
            weeklyProgressView
                .animateOnAppear(delay: 0.15)
        }
    }
    
    // MARK: - Sync Status
    
    private var syncStatusBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(network.isConnected ? JarvisTheme.accentGreen : JarvisTheme.accent)
                .frame(width: 8, height: 8)
            
            Text(network.isConnected ? "Онлайн" : "Офлайн")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.textSecondary)
            
            if network.isConnected {
                Text("• \(network.connectionType.rawValue)")
                    .font(.system(size: 12))
                    .foregroundColor(theme.textTertiary)
            }
            
            Spacer()
            
            if !network.isConnected {
                Image(systemName: "exclamationmark.icloud")
                    .font(.system(size: 14))
                    .foregroundColor(JarvisTheme.accentOrange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(theme.cardBackground.opacity(0.5))
    }
    
    // MARK: - Stat Card
    
    private func statCard(title: String, value: String, icon: String, color: Color, progress: Double? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Spacer()
                if let progress = progress {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(color)
                }
            }
            
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(theme.textPrimary)
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(theme.textSecondary)
            
            if let progress = progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color.opacity(0.2))
                            .frame(height: 4)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color)
                            .frame(width: geo.size.width * progress, height: 4)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(16)
        .frame(width: 130)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.cardBackground)
                .shadow(color: theme.cardShadow, radius: 4, y: 2)
        )
    }
    
    // MARK: - Weekly Progress
    
    private var weeklyProgressView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Активность за неделю")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textPrimary)
                .padding(.horizontal, 16)
            
            HStack(spacing: 8) {
                ForEach(weekDays, id: \.self) { day in
                    weekDayColumn(day)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .background(theme.cardBackground)
    }
    
    private func weekDayColumn(_ date: Date) -> some View {
        let completed = completedOnDay(date)
        let total = tasksOnDay(date)
        let height: CGFloat = total > 0 ? max(20, min(60, CGFloat(completed) / CGFloat(max(total, 1)) * 60)) : 8
        let isToday = Calendar.current.isDateInToday(date)
        
        return VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    total > 0 ? 
                    (completed == total ? JarvisTheme.accentGreen : JarvisTheme.accent) :
                    theme.divider
                )
                .frame(width: 32, height: height)
                .animation(.spring(response: 0.4), value: height)
            
            Text(dayLetter(date))
                .font(.system(size: 11, weight: isToday ? .bold : .regular))
                .foregroundColor(isToday ? JarvisTheme.accent : theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Computed Properties
    
    private var completedCount: Int {
        store.tasks.filter { $0.isCompleted }.count
    }
    
    private var todayCount: Int {
        store.tasks.filter { Calendar.current.isDateInToday($0.date) && !$0.isInbox }.count
    }
    
    private var inboxCount: Int {
        store.tasks.filter { $0.isInbox && !$0.isCompleted }.count
    }
    
    private var completionRate: Double {
        guard store.tasks.count > 0 else { return 0 }
        return Double(completedCount) / Double(store.tasks.count)
    }
    
    private var weekDays: [Date] {
        let calendar = Calendar.current
        let today = Date()
        return (-6...0).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }
    
    private func completedOnDay(_ date: Date) -> Int {
        store.tasks.filter { 
            Calendar.current.isDate($0.date, inSameDayAs: date) && $0.isCompleted 
        }.count
    }
    
    private func tasksOnDay(_ date: Date) -> Int {
        store.tasks.filter { 
            Calendar.current.isDate($0.date, inSameDayAs: date) && !$0.isInbox 
        }.count
    }
    
    private func dayLetter(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.locale = Locale(identifier: "ru_RU")
        return String(formatter.string(from: date).prefix(2)).uppercased()
    }
}

// MARK: - Animated Progress Ring

struct ProgressRing: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat
    
    @State private var animatedProgress: Double = 0
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.8), value: animatedProgress)
        }
        .onAppear {
            animatedProgress = progress
        }
        .onChange(of: progress) { _, newValue in
            animatedProgress = newValue
        }
    }
}

// MARK: - Task Completion Celebration

struct CompletionCelebration: View {
    @Binding var isShowing: Bool
    
    var body: some View {
        if isShowing {
            ZStack {
                ForEach(0..<12, id: \.self) { i in
                    Circle()
                        .fill(JarvisTheme.taskColors[i % JarvisTheme.taskColors.count])
                        .frame(width: 8, height: 8)
                        .offset(y: -30)
                        .rotationEffect(.degrees(Double(i) * 30))
                        .scaleEffect(isShowing ? 1 : 0)
                        .opacity(isShowing ? 0 : 1)
                        .animation(
                            .easeOut(duration: 0.5).delay(Double(i) * 0.02),
                            value: isShowing
                        )
                }
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(JarvisTheme.accentGreen)
                    .scaleEffect(isShowing ? 1.2 : 0.5)
                    .animation(.spring(response: 0.3), value: isShowing)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation { isShowing = false }
                }
            }
        }
    }
}

// MARK: - Floating Sync Button

struct FloatingSyncButton: View {
    @StateObject private var network = NetworkMonitor.shared
    @State private var isRotating = false
    let onSync: () -> Void
    
    var body: some View {
        Button(action: {
            withAnimation(.linear(duration: 0.5)) {
                isRotating = true
            }
            onSync()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isRotating = false
            }
        }) {
            ZStack {
                Circle()
                    .fill(network.isConnected ? JarvisTheme.accentBlue : JarvisTheme.accentOrange)
                    .frame(width: 44, height: 44)
                    .shadow(color: (network.isConnected ? JarvisTheme.accentBlue : JarvisTheme.accentOrange).opacity(0.4), radius: 6, y: 3)
                
                Image(systemName: network.isConnected ? "arrow.triangle.2.circlepath" : "icloud.slash")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(isRotating ? 360 : 0))
            }
        }
        .buttonStyle(.plain)
        .disabled(!network.isConnected)
    }
}

#Preview {
    TaskStatisticsView()
}
