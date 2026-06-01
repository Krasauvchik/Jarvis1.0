import SwiftUI

// MARK: - Reusable UI Components
// Extracted from StructuredMainView to eliminate duplication (DRY principle).
// These components were repeated 4-5 times across different task row variants.

/// Completion toggle circle — unified across all task row types.
/// Previously duplicated in: taskRow, taskListRow, timelineTaskCard, completedTaskRow.
struct TaskCompletionCircle: View {
    let task: PlannerTask
    let size: CGFloat
    let onToggle: () -> Void
    
    init(task: PlannerTask, size: CGFloat = 24, onToggle: @escaping () -> Void) {
        self.task = task
        self.size = size
        self.onToggle = onToggle
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(task.taskColor, lineWidth: 2)
                .frame(width: size, height: size)
            if task.isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundColor(task.taskColor)
            }
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(task.isCompleted ? "\(L10n.markIncomplete) \(task.title)" : "\(L10n.markComplete) \(task.title)")
        .accessibilityAddTraits(.isButton)
        .highPriorityGesture(
            TapGesture().onEnded { _ in onToggle() }
        )
    }
}

/// Task icon badge — circle background with SF Symbol icon.
/// Previously duplicated in: taskRow, taskListRow, inboxTaskRow, taskIconCircle.
struct TaskIconBadge: View {
    let task: PlannerTask
    let size: CGFloat
    let defaultIcon: String
    
    init(task: PlannerTask, size: CGFloat = 40, defaultIcon: String = "star.fill") {
        self.task = task
        self.size = size
        self.defaultIcon = defaultIcon
    }
    
    var body: some View {
        Circle()
            .fill(task.taskColor.opacity(0.15))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: task.icon.isEmpty ? defaultIcon : task.icon)
                    .font(.system(size: size * 0.4))
                    .foregroundColor(task.taskColor)
            )
    }
}

/// Draggable task preview — shown when dragging tasks.
/// Previously duplicated in: taskListRow.draggable, taskRow.draggable, timelineTaskCard.draggable.
struct DragPreview: View {
    let task: PlannerTask
    let theme: JarvisTheme
    
    var body: some View {
        HStack {
            Circle()
                .fill(task.taskColor)
                .frame(width: 8, height: 8)
            Text(task.title)
                .font(.system(size: 14, weight: .medium))
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(theme.cardBackground))
        .scaleEffect(1.08)
    }
}

/// Empty state view — icon + text.
/// Previously duplicated in: emptyTimelineView, emptyInboxView, emptyStateForSection.
struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String
    let actionTitle: String?
    let iconColor: Color
    let onAction: (() -> Void)?
    
    init(
        icon: String,
        title: String,
        description: String = "",
        actionTitle: String? = nil,
        iconColor: Color = JarvisTheme.accent,
        onAction: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.actionTitle = actionTitle
        self.iconColor = iconColor
        self.onAction = onAction
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: icon)
                    .font(.system(size: 44))
                    .foregroundColor(iconColor.opacity(0.6))
            }
            
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(JarvisTheme.textPrimary)
            
            if !description.isEmpty {
                Text(description)
                    .font(.system(size: 15))
                    .foregroundColor(JarvisTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            if let actionTitle, let onAction {
                Button(action: onAction) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                        Text(actionTitle)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(JarvisTheme.accent)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Safe URL Construction (replaces 20+ force unwraps)

extension URL {
    /// Safe URL construction — returns nil instead of crashing on invalid strings.
    /// Replaces `URL(string:)!` force unwraps throughout the codebase.
    static func safe(_ string: String) -> URL? {
        URL(string: string)
    }
}
