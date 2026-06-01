import SwiftUI
import Combine

// MARK: - Focus Timer / Pomodoro (inspired by Structured's built-in focus timer)
// Structured offers a Pomodoro focus timer with customizable work/break durations.

// MARK: - Focus Session Model

struct FocusSession: Identifiable, Codable {
    let id: UUID
    var taskId: UUID?
    var taskTitle: String
    var workDuration: Int       // seconds
    var breakDuration: Int      // seconds
    var completedPomodoros: Int
    var targetPomodoros: Int
    var startedAt: Date
    var endedAt: Date?
    
    init(
        id: UUID = UUID(),
        taskId: UUID? = nil,
        taskTitle: String = "",
        workDuration: Int = 25 * 60,
        breakDuration: Int = 5 * 60,
        completedPomodoros: Int = 0,
        targetPomodoros: Int = 4,
        startedAt: Date = Date(),
        endedAt: Date? = nil
    ) {
        self.id = id
        self.taskId = taskId
        self.taskTitle = taskTitle
        self.workDuration = workDuration
        self.breakDuration = breakDuration
        self.completedPomodoros = completedPomodoros
        self.targetPomodoros = targetPomodoros
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}

// MARK: - Focus Timer State

enum FocusTimerPhase: String, Codable {
    case idle
    case work
    case shortBreak
    case longBreak
    case paused
}

// MARK: - Focus Timer Manager

@MainActor @Observable
final class FocusTimerManager {
    static let shared = FocusTimerManager()
    
    var phase: FocusTimerPhase = .idle
    var timeRemaining: Int = 25 * 60  // seconds
    var currentSession: FocusSession?
    var completedToday: Int = 0
    var totalFocusMinutesToday: Int = 0
    
    // Settings
    var workMinutes: Int {
        didSet { UserDefaults.standard.set(workMinutes, forKey: "pomodoro_work_minutes") }
    }
    var shortBreakMinutes: Int {
        didSet { UserDefaults.standard.set(shortBreakMinutes, forKey: "pomodoro_short_break") }
    }
    var longBreakMinutes: Int {
        didSet { UserDefaults.standard.set(longBreakMinutes, forKey: "pomodoro_long_break") }
    }
    var longBreakAfter: Int {
        didSet { UserDefaults.standard.set(longBreakAfter, forKey: "pomodoro_long_break_after") }
    }
    
    private var timer: Timer?
    private var phaseBeforePause: FocusTimerPhase = .idle
    
    private init() {
        self.workMinutes = UserDefaults.standard.object(forKey: "pomodoro_work_minutes") as? Int ?? 25
        self.shortBreakMinutes = UserDefaults.standard.object(forKey: "pomodoro_short_break") as? Int ?? 5
        self.longBreakMinutes = UserDefaults.standard.object(forKey: "pomodoro_long_break") as? Int ?? 15
        self.longBreakAfter = UserDefaults.standard.object(forKey: "pomodoro_long_break_after") as? Int ?? 4
        loadTodayStats()
    }
    
    // MARK: - Controls
    
    func startFocus(taskId: UUID? = nil, taskTitle: String = "") {
        let session = FocusSession(
            taskId: taskId,
            taskTitle: taskTitle,
            workDuration: workMinutes * 60,
            breakDuration: shortBreakMinutes * 60,
            targetPomodoros: longBreakAfter
        )
        currentSession = session
        phase = .work
        timeRemaining = workMinutes * 60
        startTimer()
        HapticManager.shared.impact(.medium)
    }
    
    func pause() {
        guard phase == .work || phase == .shortBreak || phase == .longBreak else { return }
        phaseBeforePause = phase
        phase = .paused
        timer?.invalidate()
        timer = nil
    }
    
    func resume() {
        guard phase == .paused else { return }
        phase = phaseBeforePause
        startTimer()
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        
        // Log completed minutes
        if let session = currentSession, phase != .idle {
            let elapsed = (session.workDuration * session.completedPomodoros)
            totalFocusMinutesToday += elapsed / 60
            saveTodayStats()
            
            // Update task spentMinutes if linked
            if let taskId = session.taskId {
                var store = PlannerStore.shared
                if let idx = store.tasks.firstIndex(where: { $0.id == taskId }) {
                    store.tasks[idx].spentMinutes += elapsed / 60
                }
            }
        }
        
        phase = .idle
        currentSession = nil
        timeRemaining = workMinutes * 60
    }
    
    func skip() {
        timer?.invalidate()
        timer = nil
        transitionToNextPhase()
    }
    
    // MARK: - Timer Logic
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }
    
    private func tick() {
        guard timeRemaining > 0 else {
            timer?.invalidate()
            timer = nil
            HapticManager.shared.notification(.success)
            transitionToNextPhase()
            return
        }
        timeRemaining -= 1
    }
    
    private func transitionToNextPhase() {
        guard var session = currentSession else { return }
        
        switch phase {
        case .work:
            session.completedPomodoros += 1
            completedToday += 1
            totalFocusMinutesToday += workMinutes
            saveTodayStats()
            currentSession = session
            
            if session.completedPomodoros >= session.targetPomodoros {
                // Long break after target pomodoros
                phase = .longBreak
                timeRemaining = longBreakMinutes * 60
            } else {
                phase = .shortBreak
                timeRemaining = shortBreakMinutes * 60
            }
            startTimer()
            
        case .shortBreak, .longBreak:
            if phase == .longBreak {
                // Reset pomodoro count after long break
                session.completedPomodoros = 0
                currentSession = session
            }
            phase = .work
            timeRemaining = workMinutes * 60
            startTimer()
            
        default:
            break
        }
    }
    
    // MARK: - Persistence
    
    private func saveTodayStats() {
        let key = "pomodoro_stats_\(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)"
        UserDefaults.standard.set(completedToday, forKey: key + "_count")
        UserDefaults.standard.set(totalFocusMinutesToday, forKey: key + "_minutes")
    }
    
    private func loadTodayStats() {
        let key = "pomodoro_stats_\(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)"
        completedToday = UserDefaults.standard.integer(forKey: key + "_count")
        totalFocusMinutesToday = UserDefaults.standard.integer(forKey: key + "_minutes")
    }
    
    // MARK: - Formatted Time
    
    var formattedTime: String {
        let min = timeRemaining / 60
        let sec = timeRemaining % 60
        return String(format: "%02d:%02d", min, sec)
    }
    
    var progress: Double {
        let total: Int
        switch phase {
        case .work: total = workMinutes * 60
        case .shortBreak: total = shortBreakMinutes * 60
        case .longBreak: total = longBreakMinutes * 60
        default: return 0
        }
        guard total > 0 else { return 0 }
        return 1.0 - Double(timeRemaining) / Double(total)
    }
    
    var phaseDisplayName: String {
        switch phase {
        case .idle: return L10n.focusReady
        case .work: return L10n.focusWork
        case .shortBreak: return L10n.focusShortBreak
        case .longBreak: return L10n.focusLongBreak
        case .paused: return L10n.focusPaused
        }
    }
    
    var phaseColor: Color {
        switch phase {
        case .work: return JarvisTheme.accent
        case .shortBreak: return JarvisTheme.accentGreen
        case .longBreak: return JarvisTheme.accentBlue
        case .paused: return JarvisTheme.accentYellow
        case .idle: return JarvisTheme.accentTeal
        }
    }
}

// MARK: - Focus Timer View

struct FocusTimerView: View {
    let theme: JarvisTheme
    @Bindable private var timer = FocusTimerManager.shared
    var store: PlannerStore
    @State private var selectedTaskId: UUID?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                Text(L10n.focusTitle)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                // Timer Circle
                timerCircle
                
                // Phase label
                Text(timer.phaseDisplayName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(timer.phaseColor)
                
                // Pomodoro dots
                if let session = timer.currentSession {
                    HStack(spacing: 8) {
                        ForEach(0..<session.targetPomodoros, id: \.self) { idx in
                            Circle()
                                .fill(idx < session.completedPomodoros ? timer.phaseColor : theme.divider)
                                .frame(width: 10, height: 10)
                        }
                    }
                }
                
                // Controls
                controlButtons
                
                // Task Selector (when idle)
                if timer.phase == .idle {
                    taskSelector
                }
                
                // Today's Stats
                todayStats
                
                // Settings
                if timer.phase == .idle {
                    settingsSection
                }
            }
            .padding()
        }
    }
    
    private var timerCircle: some View {
        ZStack {
            Circle()
                .stroke(theme.divider, lineWidth: 8)
                .frame(width: 200, height: 200)
            
            Circle()
                .trim(from: 0, to: timer.progress)
                .stroke(timer.phaseColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: timer.progress)
            
            VStack(spacing: 4) {
                Text(timer.formattedTime)
                    .font(.system(size: 48, weight: .light, design: .monospaced))
                    .foregroundColor(theme.textPrimary)
                
                if let session = timer.currentSession, !session.taskTitle.isEmpty {
                    Text(session.taskTitle)
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                }
            }
        }
    }
    
    private var controlButtons: some View {
        HStack(spacing: 20) {
            if timer.phase == .idle {
                Button(action: {
                    let title = store.tasks.first(where: { $0.id == selectedTaskId })?.title ?? ""
                    timer.startFocus(taskId: selectedTaskId, taskTitle: title)
                }) {
                    Label(L10n.focusStart, systemImage: "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(JarvisTheme.accent))
                }
                .buttonStyle(.plain)
            } else if timer.phase == .paused {
                Button(action: { timer.resume() }) {
                    Label(L10n.focusResume, systemImage: "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(JarvisTheme.accentGreen))
                }
                .buttonStyle(.plain)
                
                Button(action: { timer.stop() }) {
                    Label(L10n.focusStop, systemImage: "stop.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(.red))
                }
                .buttonStyle(.plain)
            } else {
                Button(action: { timer.pause() }) {
                    Label(L10n.focusPause, systemImage: "pause.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(JarvisTheme.accentYellow))
                }
                .buttonStyle(.plain)
                
                Button(action: { timer.skip() }) {
                    Label(L10n.focusSkip, systemImage: "forward.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.textSecondary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(theme.chipBackground))
                }
                .buttonStyle(.plain)
                
                Button(action: { timer.stop() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16))
                        .foregroundColor(theme.textTertiary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(theme.chipBackground))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var taskSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.focusSelectTask)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(theme.textSecondary)
            
            let todayTasks = store.tasks.filter { !$0.isCompleted && Calendar.current.isDateInToday($0.date) }
            
            if todayTasks.isEmpty {
                Text(L10n.focusNoTasks)
                    .font(.system(size: 13))
                    .foregroundColor(theme.textTertiary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(todayTasks) { task in
                            Button(action: { selectedTaskId = task.id }) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(JarvisTheme.taskColor(for: task.colorIndex))
                                        .frame(width: 8, height: 8)
                                    Text(task.title)
                                        .font(.system(size: 13))
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(selectedTaskId == task.id ? JarvisTheme.accent.opacity(0.15) : theme.chipBackground)
                                )
                                .overlay(
                                    Capsule().stroke(selectedTaskId == task.id ? JarvisTheme.accent : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(theme.cardBackground))
    }
    
    private var todayStats: some View {
        HStack(spacing: 24) {
            VStack(spacing: 4) {
                Text("\(timer.completedToday)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(JarvisTheme.accent)
                Text(L10n.focusPomodoros)
                    .font(.system(size: 12))
                    .foregroundColor(theme.textSecondary)
            }
            
            Divider().frame(height: 40)
            
            VStack(spacing: 4) {
                Text("\(timer.totalFocusMinutesToday)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(JarvisTheme.accentGreen)
                Text(L10n.focusMinutes)
                    .font(.system(size: 12))
                    .foregroundColor(theme.textSecondary)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(theme.cardBackground))
    }
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.focusSettings)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(theme.textPrimary)
            
            HStack {
                Text(L10n.focusWorkDuration)
                    .foregroundColor(theme.textSecondary)
                Spacer()
                Stepper("\(timer.workMinutes) min", value: $timer.workMinutes, in: 5...60, step: 5)
                    .labelsHidden()
                Text("\(timer.workMinutes) min")
                    .foregroundColor(theme.textPrimary)
                    .frame(width: 55)
            }
            
            HStack {
                Text(L10n.focusShortBreakDuration)
                    .foregroundColor(theme.textSecondary)
                Spacer()
                Stepper("\(timer.shortBreakMinutes) min", value: $timer.shortBreakMinutes, in: 1...30)
                    .labelsHidden()
                Text("\(timer.shortBreakMinutes) min")
                    .foregroundColor(theme.textPrimary)
                    .frame(width: 55)
            }
            
            HStack {
                Text(L10n.focusLongBreakDuration)
                    .foregroundColor(theme.textSecondary)
                Spacer()
                Stepper("\(timer.longBreakMinutes) min", value: $timer.longBreakMinutes, in: 5...60, step: 5)
                    .labelsHidden()
                Text("\(timer.longBreakMinutes) min")
                    .foregroundColor(theme.textPrimary)
                    .frame(width: 55)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(theme.cardBackground))
    }
}
