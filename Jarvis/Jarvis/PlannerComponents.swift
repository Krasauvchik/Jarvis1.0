import SwiftUI

// MARK: - Cached Formatters

private enum CachedFormatters {
    static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "LLLL yyyy"
        return f
    }()
    
    static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "EEE"
        return f
    }()
    
    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}

// MARK: - Structured-style Date Strip

struct StructuredDateStrip: View {
    let selectedDay: Date
    let onSelectDay: (Date) -> Void
    let taskCountForDay: (Date) -> Int
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 0) {
            monthHeader
            
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(daysInRange, id: \.self) { day in
                            DateCell(
                                day: day,
                                isSelected: calendar.isDate(day, inSameDayAs: selectedDay),
                                isToday: calendar.isDateInToday(day),
                                taskCount: taskCountForDay(day)
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    onSelectDay(day)
                                }
                            }
                            .id(day)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .onAppear {
                    proxy.scrollTo(selectedDay, anchor: .center)
                }
                .onChange(of: selectedDay) { _, newDay in
                    withAnimation {
                        proxy.scrollTo(newDay, anchor: .center)
                    }
                }
            }
        }
        .background(JarvisTheme.cardBackground)
    }
    
    private var monthHeader: some View {
        HStack {
            Text(monthYearText)
                .font(.title2.weight(.bold))
                .foregroundStyle(JarvisTheme.textPrimary)
            
            Spacer()
            
            Button {
                withAnimation { onSelectDay(Date()) }
            } label: {
                Text(L10n.today)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(JarvisTheme.accent)
            }
            .bounceOnTap()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    private var monthYearText: String {
        CachedFormatters.monthYearFormatter.string(from: selectedDay).capitalized
    }
    
    private var daysInRange: [Date] {
        let start = calendar.date(byAdding: .day, value: -14, to: Date())!
        return (0..<60).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}

// MARK: - Date Cell (Structured-style)

struct DateCell: View {
    let day: Date
    let isSelected: Bool
    let isToday: Bool
    let taskCount: Int
    let action: () -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(weekdayShort)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isSelected ? .white : JarvisTheme.textTertiary)
                
                Text("\(dayNumber)")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(textColor)
                
                if taskCount > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<min(taskCount, 3), id: \.self) { _ in
                            Circle()
                                .fill(isSelected ? .white.opacity(0.8) : JarvisTheme.accent)
                                .frame(width: 4, height: 4)
                        }
                    }
                } else {
                    Spacer().frame(height: 4)
                }
            }
            .frame(width: 48, height: 64)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isToday && !isSelected ? JarvisTheme.accent : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .bounceOnTap()
    }
    
    private var textColor: Color {
        if isSelected { return .white }
        if isToday { return JarvisTheme.accent }
        return JarvisTheme.textPrimary
    }
    
    private var backgroundColor: Color {
        if isSelected { return JarvisTheme.accent }
        return .clear
    }
    
    private var weekdayShort: String {
        String(CachedFormatters.weekdayFormatter.string(from: day).prefix(2)).uppercased()
    }
    
    private var dayNumber: Int {
        calendar.component(.day, from: day)
    }
}

// MARK: - Timeline Task Block (Structured-style)

struct TaskBlockView: View {
    let task: PlannerTask
    let color: Color
    let dayStart: Date
    let hourRowHeight: CGFloat
    /// Отступ сверху сетки часов (чтобы блок совпадал со строкой по времени)
    var timelineTopPadding: CGFloat = 0
    /// Час, с которого начинается таймлайн (например 6 → строки 06:00, 07:00, …)
    var timelineStartHour: Int = 6
    let onTap: () -> Void
    let onToggle: () -> Void
    
    // MARK: - Static helpers for positioning
    
    /// Compute the Y offset for a task block within a timeline ZStack
    static func computeOffset(
        taskDate: Date,
        dayStart: Date,
        hourRowHeight: CGFloat,
        timelineTopPadding: CGFloat = 0,
        timelineStartHour: Int = 0
    ) -> CGFloat {
        let hoursFromDayStart = taskDate.timeIntervalSince(dayStart) / 3600
        let rowOffset = max(0, hoursFromDayStart - Double(timelineStartHour))
        return timelineTopPadding + CGFloat(rowOffset) * hourRowHeight
    }
    
    /// Compute block height based on duration
    static func computeHeight(durationMinutes: Int, hourRowHeight: CGFloat) -> CGFloat {
        let minutes = durationMinutes > 0 ? durationMinutes : 60
        return max(36, CGFloat(minutes) / 60 * hourRowHeight)
    }
    
    var body: some View {
        let startOffset = Self.computeOffset(
            taskDate: task.date,
            dayStart: dayStart,
            hourRowHeight: hourRowHeight,
            timelineTopPadding: timelineTopPadding,
            timelineStartHour: timelineStartHour
        )
        let height = Self.computeHeight(durationMinutes: task.durationMinutes, hourRowHeight: hourRowHeight)
        
        HStack(spacing: 10) {
            // Left color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4)
            
            // Content (tap to edit)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(task.isCompleted ? JarvisTheme.textTertiary : JarvisTheme.textPrimary)
                    .strikethrough(task.isCompleted, color: JarvisTheme.textTertiary)
                    .lineLimit(2)
                
                if !task.notes.isEmpty && height > 50 {
                    Text(task.notes)
                        .font(.caption)
                        .foregroundStyle(JarvisTheme.textTertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
            
            // Время начала и длительность
            VStack(alignment: .trailing, spacing: 2) {
                Text(timeText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(JarvisTheme.textTertiary)
                Text(durationText)
                    .font(.caption2)
                    .foregroundStyle(JarvisTheme.textTertiary.opacity(0.9))
            }
            .onTapGesture { onTap() }
            
            // Checkbox (right side) — tap toggles completion
            ZStack {
                Circle()
                    .strokeBorder(task.isCompleted ? color : JarvisTheme.textTertiary, lineWidth: 2)
                    .frame(width: 24, height: 24)
                
                if task.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(color)
                }
            }
            .frame(minWidth: 40, minHeight: 40)
            .contentShape(Rectangle())
            .onTapGesture { onToggle() }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: height - 4)
        .background(
            RoundedRectangle(cornerRadius: JarvisTheme.Dimensions.taskBlockRadius, style: .continuous)
                .fill(JarvisTheme.cardBackground)
                .shadow(color: JarvisTheme.cardShadow, radius: 4, x: 0, y: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(task.title), \(timeText), \(durationText)\(task.isCompleted ? ", \(L10n.completed)" : "")")
        .accessibilityHint(L10n.tapToEdit)
        .offset(y: startOffset + 2)
    }
    
    private var timeText: String {
        CachedFormatters.timeFormatter.string(from: task.date)
    }
    
    private var durationText: String {
        let min = task.durationMinutes > 0 ? task.durationMinutes : 60
        if min >= 60 && min % 60 == 0 {
            return "\(min / 60) ч"
        }
        return "\(min) мин"
    }
}

// MARK: - All Day Task Row

struct AllDayTaskRow: View {
    let task: PlannerTask
    let color: Color
    let onEdit: () -> Void
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4, height: 28)
            
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .strokeBorder(task.isCompleted ? color : JarvisTheme.textTertiary, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    
                    if task.isCompleted {
                        Circle()
                            .fill(color)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .buttonStyle(.plain)
            .bounceOnTap()
            
            Button(action: onEdit) {
                Text(task.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(task.isCompleted ? JarvisTheme.textTertiary : JarvisTheme.textPrimary)
                    .strikethrough(task.isCompleted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .bounceOnTap()
            
            Image(systemName: "sun.max")
                .font(.caption)
                .foregroundStyle(JarvisTheme.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: JarvisTheme.Dimensions.smallCornerRadius, style: .continuous)
                .fill(JarvisTheme.cardBackground)
                .shadow(color: JarvisTheme.cardShadow, radius: 3, x: 0, y: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(task.title)\(task.isCompleted ? ", \(L10n.completed)" : "")")
    }
}

// MARK: - Inbox Task Row (Structured-style)

struct InboxTaskRow: View {
    let task: PlannerTask
    let color: Color
    let onToggle: () -> Void
    let onSchedule: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4, height: 36)
            
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .strokeBorder(task.isCompleted ? color : JarvisTheme.textTertiary, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if task.isCompleted {
                        Circle()
                            .fill(color)
                            .frame(width: 16, height: 16)
                    }
                }
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(task.isCompleted ? JarvisTheme.textTertiary : JarvisTheme.textPrimary)
                    .strikethrough(task.isCompleted)
                
                if !task.notes.isEmpty {
                    Text(task.notes)
                        .font(.caption)
                        .foregroundStyle(JarvisTheme.textTertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Button(action: onSchedule) {
                Image(systemName: "calendar.badge.plus")
                    .font(.title3)
                    .foregroundStyle(JarvisTheme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: JarvisTheme.Dimensions.cornerRadius, style: .continuous)
                .fill(JarvisTheme.cardBackground)
                .shadow(color: JarvisTheme.cardShadow, radius: 4, x: 0, y: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Inbox: \(task.title)\(task.isCompleted ? ", \(L10n.completed)" : "")")
        .accessibilityHint(L10n.tapToEdit)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label(L10n.deleteTask, systemImage: "trash")
            }
        }
    }
}

// MARK: - Floating Add Button (Structured-style)

struct FloatingAddButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: JarvisTheme.Dimensions.floatingButtonSize,
                       height: JarvisTheme.Dimensions.floatingButtonSize)
                .background(
                    Circle()
                        .fill(JarvisTheme.accent)
                        .shadow(color: JarvisTheme.floatingButtonShadow, radius: 12, x: 0, y: 4)
                )
        }
        .buttonStyle(.plain)
        .bounceOnTap()
        .accessibilityLabel(L10n.addTask)
    }
}

// MARK: - Timeline Hour Grid

struct TimelineHourGrid: View {
    let startHour: Int
    let endHour: Int
    let hourRowHeight: CGFloat
    let currentHour: Int
    let currentMinute: Int
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Hour lines and labels
            VStack(spacing: 0) {
                ForEach(startHour..<endHour, id: \.self) { hour in
                    HStack(alignment: .top, spacing: 8) {
                        Text(String(format: "%02d:00", hour % 24))
                            .font(.caption.weight(.medium).monospacedDigit())
                            .foregroundStyle(JarvisTheme.textTertiary)
                            .frame(width: 44, alignment: .trailing)
                        
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(JarvisTheme.hourLine)
                                .frame(height: 1)
                            Spacer()
                        }
                    }
                    .frame(height: hourRowHeight)
                }
            }
            
            // Current time indicator
            if (startHour..<endHour).contains(currentHour) {
                let offset = CGFloat(currentHour - startHour) * hourRowHeight +
                             CGFloat(currentMinute) / 60 * hourRowHeight
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(JarvisTheme.nowLine)
                        .frame(width: 8, height: 8)
                    
                    Rectangle()
                        .fill(JarvisTheme.nowLine)
                        .frame(height: 2)
                }
                .offset(x: 48, y: offset - 4)
            }
        }
    }
}

// MARK: - Segmented Control (Structured-style)

struct StructuredSegmentedControl<T: Hashable>: View {
    let items: [T]
    @Binding var selection: T
    let title: (T) -> String
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.self) { item in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection = item
                    }
                } label: {
                    Text(title(item))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(selection == item ? .white : JarvisTheme.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selection == item ? JarvisTheme.accent : .clear)
                        )
                }
                .buttonStyle(.plain)
                .bounceOnTap()
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(JarvisTheme.chipBackground)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selection)
    }
}

// MARK: - Button Styles

struct StructuredPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(JarvisTheme.accent)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

struct StructuredSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(JarvisTheme.accent)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(JarvisTheme.chipBackground)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
