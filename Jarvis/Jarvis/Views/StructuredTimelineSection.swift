import SwiftUI

// MARK: - Structured Timeline Components
// Extracted from StructuredMainView to reduce God View size.
// Contains the proportional-block timeline rendering with dashed line,
// now indicator, task cards, and gap views.

struct StructuredTimelineContent: View {
    let theme: JarvisTheme
    let tasks: [PlannerTask]
    let selectedDate: Date
    let onEditTask: (PlannerTask) -> Void
    let onToggleTask: (PlannerTask) -> Void
    let onAddTaskAtTime: (Int, Int) -> Void
    
    private let hourRowHeight: CGFloat = 80
    
    var body: some View {
        let cal = Calendar.current
        let isToday = cal.isDateInToday(selectedDate)
        
        if let firstTask = tasks.first, let lastTask = tasks.last {
            let firstMinutes = taskMinutesOfDay(firstTask.date)
            let lastEnd = taskMinutesOfDay(lastTask.date) + CGFloat(max(lastTask.durationMinutes, 30))
            let totalHeight = (lastEnd / 60.0) * hourRowHeight + 60
            
            ZStack(alignment: .topLeading) {
                // Dashed vertical timeline line
                timelineDashedLine(startMinutes: firstMinutes, endMinutes: lastEnd)
                
                // Now indicator
                if isToday {
                    timelineNowIndicator()
                }
                
                // Task blocks
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    timelineTaskGroup(task: task, index: index, allTasks: tasks)
                }
            }
            .frame(height: totalHeight)
        }
    }
    
    // MARK: - Timeline Elements
    
    private func taskMinutesOfDay(_ date: Date) -> CGFloat {
        let cal = Calendar.current
        return CGFloat(cal.component(.hour, from: date)) * 60 + CGFloat(cal.component(.minute, from: date))
    }
    
    private func timelineDashedLine(startMinutes: CGFloat, endMinutes: CGFloat) -> some View {
        let startY = (startMinutes / 60.0) * hourRowHeight + 20
        let endY = (endMinutes / 60.0) * hourRowHeight + 20
        return Path { path in
            let x: CGFloat = 36
            var y = startY
            while y < endY {
                path.move(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x, y: min(y + 6, endY)))
                y += 12
            }
        }
        .stroke(theme.textTertiary.opacity(0.4), lineWidth: 2)
    }
    
    private func timelineNowIndicator() -> some View {
        let cal = Calendar.current
        let h = cal.component(.hour, from: Date())
        let m = cal.component(.minute, from: Date())
        let nowY = (CGFloat(h) + CGFloat(m) / 60.0) * hourRowHeight + 20
        return HStack(spacing: 0) {
            Text(String(format: "%02d:%02d", h, m))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(JarvisTheme.accent)
                .frame(width: 36, alignment: .trailing)
            Circle()
                .fill(JarvisTheme.accent)
                .frame(width: 10, height: 10)
                .offset(x: -5)
            Rectangle()
                .fill(JarvisTheme.accent)
                .frame(height: 2)
        }
        .offset(y: nowY - 7)
        .zIndex(50)
    }
    
    @ViewBuilder
    private func timelineTaskGroup(task: PlannerTask, index: Int, allTasks: [PlannerTask]) -> some View {
        let mins = taskMinutesOfDay(task.date)
        let taskY = (mins / 60.0) * hourRowHeight + 20
        let dur = max(task.durationMinutes, 30)
        let blockH = CGFloat(dur) / 60.0 * hourRowHeight
        let endMins = mins + CGFloat(task.durationMinutes)
        
        // Time label
        timeLabel(date: task.date)
            .offset(y: taskY - 7)
        
        // Icon circle
        taskIconCircle(task: task)
            .offset(x: 14, y: taskY - 2)
            .zIndex(10)
        
        // Card
        timelineTaskCard(task: task, blockHeight: blockH)
            .padding(.leading, 62)
            .padding(.trailing, 4)
            .offset(y: taskY)
        
        // End time
        if task.durationMinutes >= 60 {
            timeLabel(minutesOfDay: Int(endMins))
                .offset(y: taskY + blockH - 7)
        }
        
        // Gap to next task
        if index < allTasks.count - 1 {
            let nextMins = taskMinutesOfDay(allTasks[index + 1].date)
            let gap = Int(nextMins - endMins)
            if gap > 5 {
                timelineGapView(gapMinutes: gap, endMinutes: endMins)
            }
        }
    }
    
    private func timeLabel(date: Date) -> some View {
        Text(date.formatted(date: .omitted, time: .shortened))
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(theme.textTertiary)
            .frame(width: 36, alignment: .trailing)
    }
    
    private func timeLabel(minutesOfDay: Int) -> some View {
        Text(String(format: "%02d:%02d", minutesOfDay / 60, minutesOfDay % 60))
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(theme.textTertiary)
            .frame(width: 36, alignment: .trailing)
    }
    
    private func taskIconCircle(task: PlannerTask) -> some View {
        ZStack {
            Circle()
                .fill(task.taskColor.opacity(0.2))
                .frame(width: 44, height: 44)
            Image(systemName: task.icon.isEmpty ? "star.fill" : task.icon)
                .font(.system(size: 18))
                .foregroundColor(task.taskColor)
        }
    }
    
    private func timelineTaskCard(task: PlannerTask, blockHeight: CGFloat) -> some View {
        let cal = Calendar.current
        let endTime = cal.date(byAdding: .minute, value: task.durationMinutes, to: task.date) ?? task.date
        let timeRange = "\(task.date.formatted(date: .omitted, time: .shortened)) – \(endTime.formatted(date: .omitted, time: .shortened)) (\(DurationFormatter.format(task.durationMinutes)))"
        
        return HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(task.taskColor)
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(timeRange)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                
                Text(task.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(blockHeight > 60 ? 2 : 1)
                
                if !task.notes.isEmpty && blockHeight > 80 {
                    Text(task.notes)
                        .font(.system(size: 13))
                        .foregroundColor(theme.textTertiary)
                        .lineLimit(1)
                }
            }
            .padding(.leading, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            TaskCompletionCircle(task: task, size: 26) { onToggleTask(task) }
            .padding(.trailing, 8)
        }
        .frame(height: max(blockHeight - 6, 50))
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.cardBackground)
                .shadow(color: theme.cardShadow, radius: 3, y: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { onEditTask(task) }
        .contextMenu { taskContextMenuContent(task) }
        .draggable(task.id.uuidString) { DragPreview(task: task, theme: theme) }
    }
    
    @ViewBuilder
    private func timelineGapView(gapMinutes: Int, endMinutes: CGFloat) -> some View {
        let gapY = (endMinutes / 60.0) * hourRowHeight + 20 + (CGFloat(gapMinutes) / 120.0 * hourRowHeight)
        
        HStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.system(size: 12))
                .foregroundColor(JarvisTheme.accent.opacity(0.7))
            Text("\(DurationFormatter.format(gapMinutes)): \(gapMessage(gapMinutes))")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.textSecondary)
        }
        .padding(.leading, 62)
        .offset(y: gapY)
        
        if gapMinutes >= 15 {
            Button(action: {
                onAddTaskAtTime(Int(endMinutes) / 60, Int(endMinutes) % 60)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                    Text(L10n.addTask)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(JarvisTheme.accent)
            }
            .buttonStyle(.plain)
            .padding(.leading, 62)
            .offset(y: gapY + 22)
        }
    }
    
    // MARK: - Timeline Helpers
    
    private func gapMessage(_ gapMinutes: Int) -> String {
        if gapMinutes < 10 { return L10n.almostTime }
        if gapMinutes < 30 { return L10n.quickBreak }
        if gapMinutes < 60 { return L10n.timeForFocus }
        if gapMinutes < 120 { return L10n.aCanvasForIdeas }
        return L10n.plentyOfTime
    }
    
    /// Simplified context menu for timeline cards (edit + toggle only).
    /// Full context menu lives in StructuredMainView.taskContextMenu.
    @ViewBuilder
    private func taskContextMenuContent(_ task: PlannerTask) -> some View {
        Button {
            onEditTask(task)
        } label: {
            Label(L10n.editTask, systemImage: "pencil")
        }
        
        Button {
            onToggleTask(task)
        } label: {
            Label(task.isCompleted ? L10n.markIncomplete : L10n.markComplete,
                  systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark.circle")
        }
    }
}

// MARK: - Duration Formatter (localized)
// Replaces hardcoded "hr", "min", "мин" strings throughout the codebase.

enum DurationFormatter {
    static func format(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            if m == 0 { return "\(h) \(L10n.hoursShort)" }
            return "\(h) \(L10n.hoursShort), \(m) \(L10n.minutesShort)"
        }
        return "\(minutes) \(L10n.minutesShort)"
    }
}
