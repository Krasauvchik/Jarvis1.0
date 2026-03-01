import SwiftUI

// MARK: - Navigation Section

enum NavigationSection: String, CaseIterable, Identifiable {
    case inbox = "Inbox"
    case today = "Сегодня"
    case scheduled = "Запланир."
    case futurePlans = "Планы на будущее"
    case completed = "Выполнено"
    case all = "Все задачи"
    case calendarSection = "Календарь"
    case mailSection = "Почта"
    case messengers = "Мессенджеры"
    case analytics = "Аналитика"
    case projects = "Проекты"
    case chat = "Нейросеть"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .inbox: return "tray.fill"
        case .today: return "calendar"
        case .scheduled: return "calendar.badge.clock"
        case .futurePlans: return "sparkles"
        case .completed: return "checkmark.circle.fill"
        case .all: return "list.bullet"
        case .calendarSection: return "calendar.circle"
        case .mailSection: return "envelope.fill"
        case .messengers: return "bubble.left.and.bubble.right.fill"
        case .analytics: return "chart.bar.xaxis"
        case .projects: return "folder.fill"
        case .chat: return "brain.head.profile"
        }
    }
    
    var color: Color {
        switch self {
        case .inbox: return JarvisTheme.accentBlue
        case .today: return JarvisTheme.accentOrange
        case .scheduled: return JarvisTheme.accent
        case .futurePlans: return JarvisTheme.accentTeal
        case .completed: return JarvisTheme.accentGreen
        case .all: return JarvisTheme.accentPurple
        case .calendarSection: return JarvisTheme.accentBlue
        case .mailSection: return JarvisTheme.accentOrange
        case .messengers: return Color(red: 0.07, green: 0.72, blue: 0.34)
        case .analytics: return JarvisTheme.accentTeal
        case .projects: return JarvisTheme.accentOrange
        case .chat: return JarvisTheme.accentPurple
        }
    }
}

// MARK: - Sidebar View (iPad/Mac)

struct SidebarView: View {
    let theme: JarvisTheme
    @Binding var selectedSection: NavigationSection
    @ObservedObject var store: PlannerStore
    let onHide: () -> Void
    let onShowSleepCalculator: () -> Void
    let onShowSettings: () -> Void
    let onShowProfile: () -> Void
    
    @StateObject private var userProfile = UserProfile.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // App Header
            HStack {
                Circle()
                    .fill(LinearGradient(colors: [JarvisTheme.accent, JarvisTheme.accentOrange], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text("J")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    )
                
                Text("Jarvis")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                Spacer()
                
                Button(action: onHide) {
                    Image(systemName: "sidebar.leading")
                        .font(.system(size: 16))
                        .foregroundColor(theme.textSecondary)
                }
                .buttonStyle(.plain)
                .bounceOnTap()
                .help("Скрыть панель")
                .accessibilityLabel("Скрыть боковую панель")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .animateOnAppear(delay: 0)
            
            Divider().background(theme.divider)
            
            // Navigation Items
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(Array(NavigationSection.allCases.enumerated()), id: \.element.id) { index, section in
                        SidebarNavigationRow(
                            section: section,
                            isSelected: selectedSection == section,
                            count: taskCount(for: section),
                            theme: theme,
                            onSelect: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    selectedSection = section
                                }
                            },
                            onDrop: { taskID in
                                moveTask(taskID: taskID, to: section)
                            }
                        )
                        .animateOnAppear(delay: Double(index) * 0.04)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
            }
            
            Spacer()
            
            // Statistics
            VStack(spacing: 8) {
                Divider().background(theme.divider)
                
                HStack(spacing: 16) {
                    miniStatCard(value: store.tasks.count, label: "Всего", color: JarvisTheme.accent)
                    miniStatCard(value: completionPercentage, label: "%", color: JarvisTheme.accentGreen)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .animation(.spring(response: 0.4), value: store.tasks.count)
            }
            
            // Bottom Actions
            VStack(spacing: 8) {
                Divider().background(theme.divider)
                
                HStack(spacing: 12) {
                    Button(action: onShowSleepCalculator) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 16))
                            .foregroundColor(theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .bounceOnTap()
                    .help("Калькулятор сна")
                    .accessibilityLabel("Калькулятор сна")
                    
                    Button(action: onShowSettings) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16))
                            .foregroundColor(theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .bounceOnTap()
                    .help("Настройки")
                    .accessibilityLabel("Настройки")
                    
                    Spacer()
                    
                    Button(action: onShowProfile) {
                        profileAvatar
                    }
                    .buttonStyle(.plain)
                    .bounceOnTap()
                    .accessibilityLabel("Профиль")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(theme.sidebarBackground)
    }
    
    // MARK: - Private Helpers
    
    private var profileAvatar: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [JarvisTheme.accent, JarvisTheme.accentOrange], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 32, height: 32)
            
            Text(userProfile.initials)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
        }
    }
    
    private var completionPercentage: Int {
        guard store.tasks.count > 0 else { return 0 }
        return Int(Double(store.tasks.filter { $0.isCompleted }.count) / Double(store.tasks.count) * 100)
    }
    
    private func miniStatCard(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(theme.textTertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.cardBackground)
        )
    }
    
    private func taskCount(for section: NavigationSection) -> Int {
        store.taskCount(for: section)
    }
    
    private func moveTask(taskID: UUID, to section: NavigationSection) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            store.moveTask(taskID: taskID, to: section)
        }
    }
}

// MARK: - Sidebar Navigation Row

struct SidebarNavigationRow: View {
    let section: NavigationSection
    let isSelected: Bool
    let count: Int
    let theme: JarvisTheme
    let onSelect: () -> Void
    let onDrop: (UUID) -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: section.icon)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .white : section.color)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isSelected ? section.color : section.color.opacity(0.15))
                    )
                
                Text(section.rawValue)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? theme.textPrimary : theme.textSecondary)
                
                Spacer()
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isSelected ? section.color : theme.textTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? theme.cardBackground : Color.clear)
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? theme.cardBackground : Color.clear)
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(section.rawValue)\(count > 0 ? ", \(count)" : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .dockMagnificationEffect()
        .bounceOnTap()
        .dropDestination(for: String.self) { items, _ in
            if case .chat = section { return false }
            if case .calendarSection = section { return false }
            if case .mailSection = section { return false }
            if case .messengers = section { return false }
            if case .analytics = section { return false }
            if case .projects = section { return false }
            guard let taskID = items.first, let uuid = UUID(uuidString: taskID) else { return false }
            onDrop(uuid)
            return true
        }
    }
}
