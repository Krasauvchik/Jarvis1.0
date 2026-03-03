import SwiftUI

// MARK: - App Mode (Work / Personal)

enum AppMode: String, CaseIterable, Identifiable {
    case work = "work"
    case personal = "personal"
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .work: return L10n.modeWork
        case .personal: return L10n.modePersonal
        }
    }
    
    var icon: String {
        switch self {
        case .work: return "briefcase.fill"
        case .personal: return "heart.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .work: return JarvisTheme.accentBlue
        case .personal: return JarvisTheme.accentGreen
        }
    }
    
    /// Sections visible in this mode
    var visibleSections: [NavigationSection] {
        switch self {
        case .work:
            return [.inbox, .today, .scheduled, .futurePlans, .completed, .all, .calendarSection, .mailSection, .messengers, .analytics, .projects, .chat]
        case .personal:
            return [.today, .health, .scheduled, .completed, .calendarSection]
        }
    }
}

// MARK: - Navigation Section

enum NavigationSection: String, CaseIterable, Identifiable {
    case inbox = "inbox"
    case today = "today"
    case scheduled = "scheduled"
    case futurePlans = "future_plans"
    case completed = "completed"
    case all = "all"
    case health = "health"
    case calendarSection = "calendar"
    case mailSection = "mail"
    case messengers = "messengers"
    case analytics = "analytics"
    case projects = "projects"
    case chat = "chat"
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .inbox: return L10n.sectionInbox
        case .today: return L10n.sectionToday
        case .scheduled: return L10n.sectionScheduled
        case .futurePlans: return L10n.sectionFuture
        case .completed: return L10n.sectionCompleted
        case .all: return L10n.sectionAll
        case .health: return L10n.sectionHealth
        case .calendarSection: return L10n.sectionCalendar
        case .mailSection: return L10n.sectionMail
        case .messengers: return L10n.sectionMessengers
        case .analytics: return L10n.sectionAnalytics
        case .projects: return L10n.sectionProjects
        case .chat: return L10n.sectionNeural
        }
    }
    
    var icon: String {
        switch self {
        case .inbox: return "tray.fill"
        case .today: return "calendar"
        case .scheduled: return "calendar.badge.clock"
        case .futurePlans: return "sparkles"
        case .completed: return "checkmark.circle.fill"
        case .all: return "list.bullet"
        case .health: return "heart.text.square.fill"
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
        case .health: return Color(red: 1.0, green: 0.3, blue: 0.4)
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
    @Binding var appMode: AppMode
    @ObservedObject var store: PlannerStore
    let onHide: () -> Void
    let onShowSleepCalculator: () -> Void
    let onShowSettings: () -> Void
    let onShowProfile: () -> Void
    
    @StateObject private var userProfile = UserProfile.shared
    
    private var visibleSections: [NavigationSection] {
        appMode.visibleSections
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // App Header + Actions
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(LinearGradient(colors: [JarvisTheme.accent, JarvisTheme.accentOrange], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text("J")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        )
                    
                    Text("Jarvis")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                    
                    Spacer()
                    
                    Button(action: onShowSleepCalculator) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 14))
                            .foregroundColor(theme.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(theme.cardBackground))
                    }
                    .buttonStyle(.plain)
                    .bounceOnTap()
                    .help(L10n.sleepCalculator)
                    .accessibilityLabel(L10n.sleepCalculator)
                    
                    Button(action: onShowSettings) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14))
                            .foregroundColor(theme.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(theme.cardBackground))
                    }
                    .buttonStyle(.plain)
                    .bounceOnTap()
                    .help(L10n.tabSettings)
                    .accessibilityLabel(L10n.tabSettings)
                    
                    Button(action: onShowProfile) {
                        profileAvatar
                    }
                    .buttonStyle(.plain)
                    .bounceOnTap()
                    .accessibilityLabel(L10n.profileTitle)
                    
                    Button(action: onHide) {
                        Image(systemName: "sidebar.leading")
                            .font(.system(size: 14))
                            .foregroundColor(theme.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(theme.cardBackground))
                    }
                    .buttonStyle(.plain)
                    .bounceOnTap()
                    .help(L10n.hidePanel)
                    .accessibilityLabel(L10n.hideSidebar)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 6)
            .animateOnAppear(delay: 0)
            
            // Mode Toggle
            modeToggle
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            
            Divider().background(theme.divider)
            
            // Navigation Items
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(Array(visibleSections.enumerated()), id: \.element.id) { index, section in
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
            
            // Statistics at bottom
            VStack(spacing: 8) {
                Divider().background(theme.divider)
                
                HStack(spacing: 16) {
                    miniStatCard(value: store.tasks.count, label: L10n.totalTasks, color: JarvisTheme.accent)
                    miniStatCard(value: completionPercentage, label: "%", color: JarvisTheme.accentGreen)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .animation(.spring(response: 0.4), value: store.tasks.count)
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
    
    // MARK: - Mode Toggle
    
    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach(AppMode.allCases) { mode in
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        appMode = mode
                        // Reset section if not visible in new mode
                        if !mode.visibleSections.contains(selectedSection) {
                            selectedSection = .today
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(mode.localizedName)
                            .font(.system(size: 12, weight: appMode == mode ? .bold : .medium))
                    }
                    .foregroundColor(appMode == mode ? .white : theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(appMode == mode ? mode.color : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(theme.cardBackground)
        )
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
                
                Text(section.localizedName)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? theme.textPrimary : theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Spacer(minLength: 4)
                
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
                        .fixedSize()
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
        .accessibilityLabel("\(section.localizedName)\(count > 0 ? ", \(count)" : "")")
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
            if case .health = section { return false }
            guard let taskID = items.first, let uuid = UUID(uuidString: taskID) else { return false }
            onDrop(uuid)
            return true
        }
    }
}
