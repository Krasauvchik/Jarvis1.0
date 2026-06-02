import SwiftUI

// MARK: - Task Detail View (Subtasks / Comments / Time Tracking)

/// Rich task detail panel showing subtasks, activity log (comments), and time tracking.
/// Designed for the right pane on iPad/Mac or as a full-screen sheet on iPhone.
struct TaskDetailView: View {
    @ObservedObject var store: PlannerStore
    @Binding var task: PlannerTask
    @Environment(\.dismiss) private var dismiss
    
    @State private var newCommentText = ""
    @State private var logMinutes = 0
    @State private var showAddSubtask = false
    @State private var newSubtaskTitle = ""
    @State private var isBreakingDown = false
    @ObservedObject private var aiManager = DependencyContainer.shared.aiManager
    
    private var theme: JarvisTheme {
        JarvisTheme.current(for: ThemeManager.shared.currentTheme.colorScheme ?? .light)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                taskHeader
                
                Divider().background(theme.divider)
                
                // Subtasks Section
                subtasksSection
                
                Divider().background(theme.divider)
                
                // Time Tracking Section
                timeTrackingSection
                
                Divider().background(theme.divider)
                
                // Comments / Activity Log
                commentsSection
                
                // Approval Workflow
                if !task.approvalSteps.isEmpty || task.approvalStatus != .none {
                    Divider().background(theme.divider)
                    ApprovalWorkflowSection(task: $task)
                }
            }
            .padding(20)
        }
        .background(theme.background)
    }
    
    // MARK: - Header
    
    private var taskHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: task.icon)
                    .font(.system(size: 22))
                    .foregroundColor(task.taskColor)
                
                Text(task.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                Spacer()
                
                // Priority badge
                Text(task.priority.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(task.priority.color))
            }
            
            if !task.notes.isEmpty {
                Text(task.notes)
                    .font(.system(size: 14))
                    .foregroundColor(theme.textSecondary)
            }
            
            // External ID (if synced from external source)
            if let extId = task.externalId {
                HStack(spacing: 4) {
                    Image(systemName: "link")
                        .font(.system(size: 11))
                    Text("External: \(extId)")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(theme.textTertiary)
            }
            
            HStack(spacing: 16) {
                Label(task.date.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
                
                Label("\(task.durationMinutes) \(L10n.minutesShort)", systemImage: "clock")
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
                
                if task.isCompleted {
                    Label(L10n.completed, systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(JarvisTheme.accentGreen)
                }
            }
        }
    }
    
    // MARK: - Subtasks
    
    private var subtasks: [PlannerTask] {
        store.tasks.filter { $0.parentTaskId == task.id }
            .sorted { ($0.isCompleted ? 1 : 0, $0.date) < ($1.isCompleted ? 1 : 0, $1.date) }
    }
    
    private var subtasksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "list.bullet.indent")
                    .foregroundColor(JarvisTheme.accentBlue)
                Text(L10n.subtasks)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                Spacer()
                
                if !subtasks.isEmpty {
                    let done = subtasks.filter(\.isCompleted).count
                    Text("\(done)/\(subtasks.count)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.textTertiary)
                }

                // AI breakdown — split the task into subtasks
                Button { breakdownWithAI() } label: {
                    if isBreakingDown {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "wand.and.stars")
                            .foregroundColor(JarvisTheme.accentPurple)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isBreakingDown)
                .help(L10n.aiBreakdownSubtasks)

                Button { showAddSubtask.toggle() } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(JarvisTheme.accent)
                }
                .buttonStyle(.plain)
            }
            
            // Progress bar
            if !subtasks.isEmpty {
                let progress = Double(subtasks.filter(\.isCompleted).count) / Double(subtasks.count)
                ProgressView(value: progress)
                    .tint(JarvisTheme.accentGreen)
            }
            
            // Subtask list
            ForEach(subtasks) { sub in
                subtaskRow(sub)
            }
            
            // Add subtask inline
            if showAddSubtask {
                HStack {
                    Image(systemName: "circle")
                        .foregroundColor(theme.textTertiary)
                    TextField(L10n.addSubtask, text: $newSubtaskTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .onSubmit { addSubtask() }
                    Button { addSubtask() } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(JarvisTheme.accentGreen)
                    }
                    .buttonStyle(.plain)
                    .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.cardBackground)
                )
            }
        }
    }
    
    private func subtaskRow(_ sub: PlannerTask) -> some View {
        HStack(spacing: 10) {
            Button {
                var updated = sub
                updated.isCompleted.toggle()
                updated.completedAt = updated.isCompleted ? Date() : nil
                store.update(updated)
            } label: {
                Image(systemName: sub.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(sub.isCompleted ? JarvisTheme.accentGreen : theme.textTertiary)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            
            Text(sub.title)
                .font(.system(size: 14))
                .foregroundColor(sub.isCompleted ? theme.textTertiary : theme.textPrimary)
                .strikethrough(sub.isCompleted)
            
            Spacer()
            
            if sub.spentMinutes > 0 {
                Text(L10n.minutesShortValue(sub.spentMinutes))
                    .font(.system(size: 11))
                    .foregroundColor(theme.textTertiary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(sub.isCompleted ? theme.cardBackground.opacity(0.5) : theme.cardBackground)
        )
        .contextMenu {
            Button(role: .destructive) { store.delete(sub) } label: {
                Label(L10n.deleteTask, systemImage: "trash")
            }
        }
    }
    
    private func addSubtask() {
        let trimmed = newSubtaskTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let sub = PlannerTask(
            title: trimmed,
            date: task.date,
            durationMinutes: 15,
            colorIndex: task.colorIndex,
            icon: "circle",
            categoryId: task.categoryId,
            priority: task.priority,
            parentTaskId: task.id
        )
        store.add(sub)
        newSubtaskTitle = ""
    }

    /// Asks the AI to split this task into subtasks and adds the ones that don't already exist.
    private func breakdownWithAI() {
        guard !isBreakingDown else { return }
        isBreakingDown = true
        let parentTitle = task.title
        let parentNotes = task.notes
        Task {
            let titles = await aiManager.breakdownTask(title: parentTitle, notes: parentNotes)
            await MainActor.run {
                let existing = Set(subtasks.map { $0.title.lowercased() })
                for title in titles where !existing.contains(title.lowercased()) {
                    let sub = PlannerTask(
                        title: title,
                        date: task.date,
                        durationMinutes: 15,
                        colorIndex: task.colorIndex,
                        icon: "circle",
                        categoryId: task.categoryId,
                        priority: task.priority,
                        parentTaskId: task.id
                    )
                    store.add(sub)
                }
                isBreakingDown = false
            }
        }
    }

    // MARK: - Time Tracking
    
    private var timeTrackingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "timer")
                    .foregroundColor(JarvisTheme.accentOrange)
                Text(L10n.timeTracking)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                Spacer()
            }
            
            // Total time
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.totalSpent)
                        .font(.system(size: 12))
                        .foregroundColor(theme.textTertiary)
                    Text(formatTime(task.spentMinutes))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.estimated)
                        .font(.system(size: 12))
                        .foregroundColor(theme.textTertiary)
                    Text(formatTime(task.durationMinutes))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(theme.textSecondary)
                }
                
                Spacer()
                
                // Progress circle
                let progress = task.durationMinutes > 0 ? min(1.0, Double(task.spentMinutes) / Double(task.durationMinutes)) : 0
                ZStack {
                    Circle()
                        .stroke(theme.cardBackground, lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(progress > 1 ? Color.red : JarvisTheme.accentGreen, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                }
                .frame(width: 44, height: 44)
            }
            
            // Log time
            HStack {
                Stepper(value: $logMinutes, in: 0...480, step: 15) {
                    Text(L10n.logTime + ": \(logMinutes) \(L10n.minutesShort)")
                        .font(.system(size: 14))
                }
                
                Button {
                    guard logMinutes > 0 else { return }
                    task.spentMinutes += logMinutes
                    // Also add a comment for the time log
                    let comment = TaskComment(
                        text: "⏱ \(L10n.loggedTime): \(logMinutes) \(L10n.minutesShort)",
                        spentMinutes: logMinutes
                    )
                    task.comments.append(comment)
                    store.update(task)
                    logMinutes = 0
                } label: {
                    Text(L10n.logTime)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(JarvisTheme.accentOrange))
                }
                .buttonStyle(.plain)
                .disabled(logMinutes == 0)
            }
            
            // Time log entries from comments
            let timeLogs = task.comments.filter { $0.spentMinutes != nil && $0.spentMinutes! > 0 }
            if !timeLogs.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.timeLog)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.textSecondary)
                    ForEach(timeLogs) { log in
                        HStack {
                            Text(log.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 11))
                                .foregroundColor(theme.textTertiary)
                            Spacer()
                            Text("+\(log.spentMinutes ?? 0) \(L10n.minutesShort)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(JarvisTheme.accentOrange)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Comments / Activity Log
    
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right")
                    .foregroundColor(JarvisTheme.accentPurple)
                Text(L10n.comments)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Text("\(task.comments.count)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.textTertiary)
            }
            
            if task.comments.isEmpty {
                Text(L10n.noComments)
                    .font(.system(size: 13))
                    .foregroundColor(theme.textTertiary)
                    .padding(.vertical, 10)
            } else {
                ForEach(task.comments) { comment in
                    commentRow(comment)
                }
            }
            
            // Add comment
            HStack(spacing: 8) {
                TextField(L10n.addComment, text: $newCommentText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .lineLimit(1...4)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(theme.cardBackground)
                    )
                
                Button {
                    let trimmed = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    let comment = TaskComment(text: trimmed)
                    task.comments.append(comment)
                    store.update(task)
                    newCommentText = ""
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? theme.textTertiary : JarvisTheme.accent)
                }
                .buttonStyle(.plain)
                .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
    
    private func commentRow(_ comment: TaskComment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(comment.authorName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Text(comment.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundColor(theme.textTertiary)
            }
            
            Text(comment.text)
                .font(.system(size: 14))
                .foregroundColor(theme.textPrimary)
            
            if let mins = comment.spentMinutes, mins > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text("+\(mins) \(L10n.minutesShort)")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(JarvisTheme.accentOrange)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.cardBackground)
        )
    }
    
    // MARK: - Formatting Helpers
    
    private func formatTime(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }
}
