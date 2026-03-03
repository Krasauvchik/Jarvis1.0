#if !os(watchOS)
import SwiftUI
import Combine

// MARK: - Messenger Service

enum MessengerType: String, CaseIterable, Identifiable {
    case whatsapp = "WhatsApp"
    case telegram = "Telegram"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .whatsapp: return "message.fill"
        case .telegram: return "paperplane.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .whatsapp: return Color(red: 0.07, green: 0.72, blue: 0.34) // #12B886
        case .telegram: return Color(red: 0.16, green: 0.58, blue: 0.89) // #2A95E3
        }
    }
    
    /// URL scheme to open the messenger app
    var appScheme: String {
        switch self {
        case .whatsapp: return "whatsapp://"
        case .telegram: return "tg://"
        }
    }
    
    /// URL for sending a text message
    func sendURL(text: String) -> URL? {
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        switch self {
        case .whatsapp:
            return URL(string: "whatsapp://send?text=\(encoded)")
        case .telegram:
            return URL(string: "tg://msg?text=\(encoded)")
        }
    }
    
    /// Web fallback URL
    func webURL(text: String) -> URL? {
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        switch self {
        case .whatsapp:
            return URL(string: "https://wa.me/?text=\(encoded)")
        case .telegram:
            return URL(string: "https://t.me/share/url?text=\(encoded)")
        }
    }
}

// MARK: - Messenger Service

@MainActor
final class MessengerService: ObservableObject {
    static let shared = MessengerService()
    
    @Published var lastShareResult: ShareResult?
    
    struct ShareResult: Identifiable {
        let id = UUID()
        let messenger: MessengerType
        let success: Bool
        let message: String
    }
    
    private init() {}
    
    /// Format a single task for sharing
    func formatTask(_ task: PlannerTask) -> String {
        var lines: [String] = []
        lines.append("📋 \(task.title)")
        if !task.isAllDay {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yyyy HH:mm"
            lines.append("📅 \(formatter.string(from: task.date))")
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yyyy"
            lines.append("📅 \(formatter.string(from: task.date)) (\(L10n.allDay))")
        }
        if task.durationMinutes > 0 {
            lines.append("⏱ \(task.durationMinutes) \(L10n.shareMinutes)")
        }
        if task.priority != .medium {
            lines.append("❗ \(L10n.sharePriority): \(task.priority.rawValue)")
        }
        if !task.notes.isEmpty {
            lines.append("📝 \(task.notes)")
        }
        lines.append("\n— \(L10n.shareSentFrom)")
        return lines.joined(separator: "\n")
    }
    
    /// Format multiple tasks for sharing (e.g. daily plan)
    func formatDailyPlan(tasks: [PlannerTask], date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"
        dateFormatter.locale = Locale(identifier: "ru_RU")
        
        var lines: [String] = []
        lines.append("📌 \(L10n.sharePlanFor) \(dateFormatter.string(from: date))")
        lines.append("")
        
        let sorted = tasks.sorted { $0.date < $1.date }
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        for task in sorted {
            let status = task.isCompleted ? "✅" : "⬜"
            let time = task.isAllDay ? L10n.allDay : timeFormatter.string(from: task.date)
            lines.append("\(status) \(time) — \(task.title)")
        }
        
        let completed = tasks.filter(\.isCompleted).count
        lines.append("")
        lines.append("📊 \(L10n.shareCompleted): \(completed)/\(tasks.count)")
        lines.append("\n— Jarvis Planner")
        return lines.joined(separator: "\n")
    }
    
    /// Share text via messenger
    func share(text: String, via messenger: MessengerType) {
        // Try native app first
        if let appURL = messenger.sendURL(text: text), canOpen(appURL) {
            openURL(appURL)
            lastShareResult = ShareResult(messenger: messenger, success: true, message: "\(L10n.shareOpenedIn) \(messenger.rawValue)")
            return
        }
        
        // Fallback to web
        if let webURL = messenger.webURL(text: text) {
            openURL(webURL)
            lastShareResult = ShareResult(messenger: messenger, success: true, message: "\(L10n.shareWebOpened) \(messenger.rawValue)")
            return
        }
        
        lastShareResult = ShareResult(messenger: messenger, success: false, message: "\(messenger.rawValue) \(L10n.shareNotInstalled)")
    }
    
    /// Share a single task
    func shareTask(_ task: PlannerTask, via messenger: MessengerType) {
        share(text: formatTask(task), via: messenger)
    }
    
    /// Share daily plan
    func shareDailyPlan(tasks: [PlannerTask], date: Date, via messenger: MessengerType) {
        share(text: formatDailyPlan(tasks: tasks, date: date), via: messenger)
    }
    
    private func canOpen(_ url: URL) -> Bool {
        #if canImport(UIKit)
        return UIApplication.shared.canOpenURL(url)
        #elseif canImport(AppKit)
        return NSWorkspace.shared.urlForApplication(toOpen: url) != nil
        #else
        return false
        #endif
    }
    
    private func openURL(_ url: URL) {
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #elseif canImport(AppKit)
        NSWorkspace.shared.open(url)
        #endif
    }
}

// MARK: - Messenger Share Sheet

struct MessengerShareSheet: View {
    let tasks: [PlannerTask]
    let date: Date
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @StateObject private var messenger = MessengerService.shared
    @State private var shareMode: ShareMode = .dailyPlan
    @State private var selectedTask: PlannerTask?
    @State private var showToast = false
    @State private var toastMessage = ""
    
    enum ShareMode: String, CaseIterable {
        case dailyPlan = "daily_plan"
        case singleTask = "single_task"
        
        var localizedName: String {
            switch self {
            case .dailyPlan: return L10n.shareDayPlan
            case .singleTask: return L10n.shareSingleTask
            }
        }
    }
    
    private var theme: JarvisTheme {
        JarvisTheme.current(for: colorScheme)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Mode picker
                Picker(L10n.shareModePicker, selection: $shareMode) {
                    ForEach(ShareMode.allCases, id: \.self) { mode in
                        Text(mode.localizedName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Task picker (for single task mode)
                if shareMode == .singleTask {
                    if tasks.isEmpty {
                        Text(L10n.shareNoTasks)
                            .foregroundColor(theme.textSecondary)
                            .padding(.top, 30)
                    } else {
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(tasks) { task in
                                    taskSelectRow(task)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                } else {
                    // Preview of daily plan
                    previewCard
                }
                
                Spacer()
                
                // Messenger buttons
                HStack(spacing: 24) {
                    ForEach(MessengerType.allCases) { type in
                        messengerButton(type)
                    }
                }
                .padding(.bottom, 20)
            }
            .padding(.top)
            .navigationTitle(L10n.shareTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.shareClose) { dismiss() }
                }
            }
            .overlay(alignment: .bottom) {
                if showToast {
                    toastView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
    
    private func taskSelectRow(_ task: PlannerTask) -> some View {
        let isSelected = selectedTask?.id == task.id
        return Button {
            selectedTask = task
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(task.taskColor)
                    .frame(width: 10, height: 10)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(theme.textPrimary)
                    if !task.isAllDay {
                        Text(task.date.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 12))
                            .foregroundColor(theme.textSecondary)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(JarvisTheme.accent)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? JarvisTheme.accent.opacity(0.1) : theme.cardBackground)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var previewCard: some View {
        let text = messenger.formatDailyPlan(tasks: tasks, date: date)
        return ScrollView {
            Text(text)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(theme.textPrimary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.cardBackground)
                )
                .padding(.horizontal)
        }
    }
    
    private func messengerButton(_ type: MessengerType) -> some View {
        Button {
            performShare(via: type)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(type.color)
                    )
                
                Text(type.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textPrimary)
            }
        }
        .buttonStyle(.plain)
    }
    
    private func performShare(via type: MessengerType) {
        switch shareMode {
        case .dailyPlan:
            messenger.shareDailyPlan(tasks: tasks, date: date, via: type)
        case .singleTask:
            if let task = selectedTask {
                messenger.shareTask(task, via: type)
            } else if let first = tasks.first {
                messenger.shareTask(first, via: type)
            }
        }
        toastMessage = messenger.lastShareResult?.message ?? L10n.shareSent
        withAnimation(.spring(response: 0.3)) { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showToast = false }
        }
    }
    
    private var toastView: some View {
        Text(toastMessage)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.75))
            )
            .padding(.bottom, 80)
    }
}
#endif
