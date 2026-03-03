import SwiftUI

// MARK: - Timeline View Mode

enum TimelineViewMode: String, CaseIterable, Identifiable {
    case day = "Day"
    case multiDay = "Multi-Day"
    case week = "Week"
    case month = "Month"
    
    var id: String { rawValue }
}

// MARK: - Timeline Block Frames (для расчёта часа при дропе)

struct TimelineBlockFramesKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] { [:] }
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, n in n }
    }
}

// MARK: - Timeline Panel (iPad/Mac right column)

struct TimelinePanelView: View {
    let theme: JarvisTheme
    @Binding var selectedDate: Date
    @ObservedObject var store: PlannerStore
    let onEditTask: (PlannerTask) -> Void
    let onToggleTask: (PlannerTask) -> Void
    
    @State private var timelineBlockFrames: [UUID: CGRect] = [:]
    @State private var timelineDraggingTaskId: UUID?
    @State private var timelineDragOffset: CGSize = .zero
    @State private var viewMode: TimelineViewMode = .day
    /// Показываем целевое время при перетаскивании (Day view)
    @State private var dragTargetTimeLabel: String?
    @State private var dragTargetY: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with month title and navigation
            headerBar
            
            // View mode picker (Day / Multi-Day / Week / Month)
            viewModePicker
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            
            // Week strip
            weekStripLarge
            
            Divider().background(theme.divider)
            
            // Content based on view mode
            Group {
                switch viewMode {
                case .day:
                    ScrollView { timelineContent }
                case .multiDay:
                    ScrollView { multiDayContent }
                case .week:
                    ScrollView { weekContent }
                case .month:
                    monthContent
                }
            }
        }
        .background(theme.background)
    }
    
    // MARK: - Header Bar (Month Title + Nav)
    
    private var headerBar: some View {
        HStack {
            HStack(spacing: 6) {
                Text(selectedDate.formatted(.dateTime.month(.wide)))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                Text(selectedDate.formatted(.dateTime.year()))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(JarvisTheme.accent)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
            }
            
            Spacer()
            
            dateNavigation
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - View Mode Picker
    
    private var viewModePicker: some View {
        HStack(spacing: 0) {
            ForEach(TimelineViewMode.allCases) { mode in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewMode = mode
                    }
                }) {
                    Text(mode.rawValue)
                        .font(.system(size: 13, weight: viewMode == mode ? .semibold : .medium))
                        .foregroundColor(viewMode == mode ? .white : theme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(viewMode == mode ? JarvisTheme.accent : Color.clear)
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
    
    // MARK: - Date Navigation
    
    private var dateNavigation: some View {
        HStack(spacing: 4) {
            Button(action: { moveDate(by: -navigationStep) }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Назад")
            
            Rectangle()
                .fill(theme.divider)
                .frame(width: 1, height: 18)
            
            Button(action: { moveDate(by: navigationStep) }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Вперёд")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.cardBackground)
        )
    }
    
    private var navigationStep: Int {
        switch viewMode {
        case .day: return 1
        case .multiDay: return 3
        case .week: return 7
        case .month: return 30
        }
    }
    
    // MARK: - Week Strip Large
    
    private var weekStripLarge: some View {
        HStack(spacing: 0) {
            ForEach(getCurrentWeekDays(), id: \.self) { date in
                weekDayCell(date: date)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private func weekDayCell(date: Date) -> some View {
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let isToday = Calendar.current.isDateInToday(date)
        let taskCount = store.tasksForDay(date).filter { !$0.isInbox && !$0.isCompleted }.count
        
        return Button(action: { selectedDate = date }) {
            VStack(spacing: 4) {
                Text(date.formatted(.dateTime.weekday(.short)))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textTertiary)
                
                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isSelected ? .white : (isToday ? JarvisTheme.accent : theme.textPrimary))
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(isSelected ? JarvisTheme.accent : (isToday ? JarvisTheme.accent.opacity(0.15) : Color.clear))
                    )
                
                HStack(spacing: 2) {
                    ForEach(0..<Swift.min(taskCount, 4), id: \.self) { i in
                        Circle()
                            .fill(JarvisTheme.taskColors[i % JarvisTheme.taskColors.count])
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(date.formatted(.dateTime.weekday(.wide))), \(taskCount) задач")
        .dropDestination(for: String.self) { items, _ in
            if let taskID = items.first, let uuid = UUID(uuidString: taskID) {
                moveTaskToDate(uuid, date: date)
                return true
            }
            return false
        }
    }
    
    // MARK: - Timeline Content
    
    private var timelineContent: some View {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: selectedDate)
        let dayTasks = store.tasksForDay(selectedDate).filter { !$0.isInbox && !$0.isCompleted }
        let hourRowHeight = JarvisTheme.Dimensions.hourRowHeight
        let timelineStartHour = 0
        let timelineEndHour = 25
        let timelineTopPadding: CGFloat = 16
        let currentHour = cal.component(.hour, from: Date())
        let currentMinute = cal.component(.minute, from: Date())
        
        return ZStack(alignment: .topLeading) {
            // Hour grid
            VStack(alignment: .leading, spacing: 0) {
                ForEach(timelineStartHour..<timelineEndHour, id: \.self) { hour in
                    HStack(alignment: .top, spacing: 8) {
                        Text(String(format: "%02d:00", hour % 24))
                            .font(.caption.weight(.medium).monospacedDigit())
                            .foregroundColor(theme.textTertiary)
                            .frame(width: 40, alignment: .trailing)
                        
                        Rectangle()
                            .fill(theme.hourLine)
                            .frame(height: 1)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(height: hourRowHeight)
                    .contentShape(Rectangle())
                    .dropDestination(for: String.self) { items, _ in
                        guard let taskID = items.first, let uuid = UUID(uuidString: taskID) else { return false }
                        withAnimation(.easeOut(duration: 0.25)) {
                            moveTaskToDateAndTime(taskID: uuid, date: selectedDate, hour: hour % 24, minute: 0)
                        }
                        return true
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, timelineTopPadding)
            
            // Current time indicator
            if cal.isDateInToday(selectedDate) {
                let nowOffset = timelineTopPadding + (CGFloat(currentHour - timelineStartHour) + CGFloat(currentMinute) / 60.0) * hourRowHeight
                HStack(spacing: 4) {
                    Circle()
                        .fill(JarvisTheme.accent)
                        .frame(width: 10, height: 10)
                    Rectangle()
                        .fill(JarvisTheme.accent)
                        .frame(height: 2)
                }
                .offset(y: nowOffset - 5)
                .padding(.leading, 56)
                .padding(.trailing, 20)
                .zIndex(50)
                .accessibilityLabel("Текущее время")
            }
            
            // Task blocks
            ForEach(dayTasks) { task in
                if !task.isAllDay {
                    let isDragging = timelineDraggingTaskId == task.id
                    TaskBlockView(
                        task: task,
                        color: task.taskColor,
                        dayStart: dayStart,
                        hourRowHeight: hourRowHeight,
                        timelineTopPadding: timelineTopPadding,
                        timelineStartHour: timelineStartHour,
                        onTap: { onEditTask(task) },
                        onToggle: { onToggleTask(task) }
                    )
                    .opacity(isDragging ? 0.6 : 1.0)
                    .scaleEffect(isDragging ? 1.04 : 1.0)
                    .offset(y: isDragging ? timelineDragOffset.height : 0)
                    .zIndex(isDragging ? 100 : 0)
                    .gesture(
                        DragGesture(minimumDistance: 6)
                            .onChanged { value in
                                if timelineDraggingTaskId == nil {
                                    timelineDraggingTaskId = task.id
                                }
                                if timelineDraggingTaskId == task.id {
                                    timelineDragOffset = CGSize(width: 0, height: value.translation.height)
                                    
                                    // Calculate target time for visual indicator
                                    let h = cal.component(.hour, from: task.date)
                                    let m = cal.component(.minute, from: task.date)
                                    let currentMinutes = Double(h * 60 + m)
                                    let draggedMinutes = Double(value.translation.height) / Double(hourRowHeight) * 60.0
                                    let totalMinutes = currentMinutes + draggedMinutes
                                    let snapped = max(0, min(24 * 60 - 1, Int(round(totalMinutes / 15.0) * 15.0)))
                                    let targetH = snapped / 60
                                    let targetM = snapped % 60
                                    dragTargetTimeLabel = String(format: "%02d:%02d", targetH, targetM)
                                    
                                    // Position for the label
                                    let targetOffset = timelineTopPadding + CGFloat(Double(snapped) / 60.0) * hourRowHeight
                                    dragTargetY = targetOffset
                                }
                            }
                            .onEnded { value in
                                guard timelineDraggingTaskId == task.id else { return }
                                let h = cal.component(.hour, from: task.date)
                                let m = cal.component(.minute, from: task.date)
                                let currentMinutes = Double(h * 60 + m)
                                let draggedMinutes = Double(value.translation.height) / Double(hourRowHeight) * 60.0
                                let totalMinutes = currentMinutes + draggedMinutes
                                let snapped = max(0, min(24 * 60 - 1, Int(round(totalMinutes / 15.0) * 15.0)))
                                let newHour = snapped / 60
                                let newMinute = snapped % 60
                                withAnimation(.easeOut(duration: 0.25)) {
                                    moveTaskToDateAndTime(taskID: task.id, date: selectedDate, hour: newHour, minute: newMinute)
                                }
                                timelineDraggingTaskId = nil
                                timelineDragOffset = .zero
                                dragTargetTimeLabel = nil
                            }
                    )
                    .draggable(task.id.uuidString) {
                        HStack {
                            Circle().fill(task.taskColor).frame(width: 8, height: 8)
                            Text(task.title).font(.system(size: 14, weight: .medium))
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(theme.cardBackground))
                    }
                    .padding(.leading, 68)
                    .padding(.trailing, 20)
                }
            }
        }
        .coordinateSpace(name: "timeline")
        .overlay(alignment: .topLeading) {
            // Drag target time indicator
            if let label = dragTargetTimeLabel, timelineDraggingTaskId != nil {
                HStack(spacing: 4) {
                    Text(label)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(JarvisTheme.accent))
                    
                    Rectangle()
                        .fill(JarvisTheme.accent.opacity(0.5))
                        .frame(height: 1)
                }
                .offset(y: dragTargetY - 10)
                .padding(.leading, 12)
                .padding(.trailing, 20)
                .transition(.opacity)
                .animation(.easeOut(duration: 0.1), value: label)
            }
        }
        .frame(minHeight: CGFloat(timelineEndHour - timelineStartHour) * hourRowHeight)
        .animation(.easeOut(duration: 0.25), value: dayTasks.map { "\($0.id)\($0.date.timeIntervalSince1970)" })
    }
    
    // MARK: - Multi-Day Content (4 days with hour grid, Structured-style)
    
    private var multiDayContent: some View {
        let cal = Calendar.current
        let days = (-1...2).compactMap { cal.date(byAdding: .day, value: $0, to: selectedDate) }
        let hourRowHeight = JarvisTheme.Dimensions.hourRowHeight
        let startHour = 0
        let endHour = 24
        
        return VStack(spacing: 0) {
            // Day headers row — also drop targets for quick date changes
            HStack(spacing: 0) {
                Color.clear.frame(width: 44) // spacer for hour labels
                ForEach(days, id: \.self) { date in
                    let isToday = cal.isDateInToday(date)
                    VStack(spacing: 2) {
                        Text(date.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(theme.textTertiary)
                        Text(date.formatted(.dateTime.day()))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(isToday ? .white : theme.textPrimary)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(isToday ? JarvisTheme.accent : Color.clear))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .dropDestination(for: String.self) { items, _ in
                        guard let taskID = items.first, let uuid = UUID(uuidString: taskID) else { return false }
                        withAnimation(.easeOut(duration: 0.25)) {
                            moveTaskToDate(uuid, date: date)
                        }
                        return true
                    } isTargeted: { targeted in
                        // Visual feedback handled by overlay below
                    }
                }
            }
            .padding(.vertical, 8)
            
            Divider().background(theme.divider)
            
            // Hour grid with tasks
            ZStack(alignment: .topLeading) {
                // Hour rows
                VStack(spacing: 0) {
                    ForEach(startHour..<endHour, id: \.self) { hour in
                        HStack(spacing: 0) {
                            Text(hourLabelAMPM(hour))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(theme.textTertiary)
                                .frame(width: 40, alignment: .trailing)
                                .padding(.trailing, 4)
                            
                            Rectangle()
                                .fill(theme.hourLine)
                                .frame(height: 0.5)
                        }
                        .frame(height: hourRowHeight)
                    }
                }
                
                // Column dividers + task blocks
                HStack(alignment: .top, spacing: 0) {
                    Color.clear.frame(width: 44) // spacer for hour labels area
                    
                    ForEach(Array(days.enumerated()), id: \.offset) { idx, date in
                        let dayTasks = store.tasksForDay(date)
                            .filter { !$0.isInbox && !$0.isCompleted && !$0.isAllDay }
                            .sorted { $0.date < $1.date }
                        let dayStart = cal.startOfDay(for: date)
                        
                        ZStack(alignment: .top) {
                            // Invisible drop target
                            Color.clear
                            
                            // Tasks positioned at their time
                            ForEach(dayTasks) { task in
                                multiDayTaskBlock(
                                    task: task,
                                    dayStart: dayStart,
                                    hourRowHeight: hourRowHeight,
                                    startHour: startHour
                                )
                                .draggable(task.id.uuidString) {
                                    HStack {
                                        Circle().fill(task.taskColor).frame(width: 8, height: 8)
                                        Text(task.title).font(.system(size: 12, weight: .medium))
                                    }
                                    .padding(6)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(theme.cardBackground))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .contentShape(Rectangle())
                        .dropDestination(for: String.self) { items, location in
                            guard let taskID = items.first, let uuid = UUID(uuidString: taskID) else { return false }
                            let minutesFromTop = Double(location.y) / Double(hourRowHeight) * 60.0
                            let totalMinutes = Double(startHour) * 60.0 + minutesFromTop
                            let snapped = max(0, min(24 * 60 - 1, Int(round(totalMinutes / 15.0) * 15.0)))
                            withAnimation(.easeOut(duration: 0.25)) {
                                moveTaskToDateAndTime(taskID: uuid, date: date, hour: snapped / 60, minute: snapped % 60)
                            }
                            return true
                        } isTargeted: { targeted in
                            // Highlight handled by overlay
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(Color.clear, lineWidth: 0)
                        )
                        
                        // Column divider
                        if idx < days.count - 1 {
                            Rectangle()
                                .fill(theme.divider.opacity(0.5))
                                .frame(width: 0.5)
                                .frame(height: CGFloat(endHour - startHour) * hourRowHeight)
                        }
                    }
                }
            }
            .frame(minHeight: CGFloat(endHour - startHour) * hourRowHeight)
        }
        .padding(.leading, 4)
    }
    
    // MARK: - Multi-Day Task Block (Google Calendar-style card)
    
    private func multiDayTaskBlock(task: PlannerTask, dayStart: Date, hourRowHeight: CGFloat, startHour: Int) -> some View {
        let cal = Calendar.current
        let taskHour = cal.component(.hour, from: task.date)
        let taskMinute = cal.component(.minute, from: task.date)
        let rowOffset = CGFloat(taskHour - startHour) + CGFloat(taskMinute) / 60.0
        let yOffset = max(0, rowOffset * hourRowHeight)
        let durationMinutes = task.durationMinutes > 0 ? task.durationMinutes : 60
        let blockHeight = max(28, CGFloat(durationMinutes) / 60.0 * hourRowHeight)
        
        return VStack(alignment: .leading, spacing: 1) {
            Text(task.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(blockHeight > 50 ? 3 : 1)
                .minimumScaleFactor(0.7)
            
            Text(shortTimeLabel(task.date))
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: blockHeight, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(task.taskColor.opacity(0.85))
        )
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { onEditTask(task) }
        .padding(.horizontal, 2)
        .offset(y: yOffset)
        .accessibilityLabel("\(task.title), \(shortTimeLabel(task.date))")
    }
    
    // MARK: - Week Content (7-day hour grid, Structured-style)
    
    private var weekContent: some View {
        let cal = Calendar.current
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))!
        let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
        let hourRowHeight = JarvisTheme.Dimensions.hourRowHeight
        let startHour = 0
        let endHour = 24
        
        return VStack(spacing: 0) {
            // Header row for 7 days — also drop targets for quick date changes
            HStack(spacing: 0) {
                Color.clear.frame(width: 40) // spacer for hour labels
                ForEach(days, id: \.self) { date in
                    let isToday = cal.isDateInToday(date)
                    VStack(spacing: 2) {
                        Text(date.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(theme.textTertiary)
                        
                        Text(date.formatted(.dateTime.day()))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(isToday ? .white : theme.textPrimary)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle().fill(isToday ? JarvisTheme.accent : Color.clear)
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .dropDestination(for: String.self) { items, _ in
                        guard let taskID = items.first, let uuid = UUID(uuidString: taskID) else { return false }
                        withAnimation(.easeOut(duration: 0.25)) {
                            moveTaskToDate(uuid, date: date)
                        }
                        return true
                    } isTargeted: { targeted in
                        // Visual feedback
                    }
                }
            }
            .padding(.vertical, 8)
            
            Divider().background(theme.divider)
            
            // Hour grid with task icon circles
            ZStack(alignment: .topLeading) {
                // Hour rows
                VStack(spacing: 0) {
                    ForEach(startHour..<endHour, id: \.self) { hour in
                        HStack(spacing: 0) {
                            Text(hourLabelAMPM(hour))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(theme.textTertiary)
                                .frame(width: 36, alignment: .trailing)
                                .padding(.trailing, 4)
                            
                            Rectangle()
                                .fill(theme.hourLine)
                                .frame(height: 0.5)
                        }
                        .frame(height: hourRowHeight)
                    }
                }
                
                // Column dividers + task circles
                HStack(alignment: .top, spacing: 0) {
                    Color.clear.frame(width: 40) // spacer for hour labels
                    
                    ForEach(Array(days.enumerated()), id: \.offset) { idx, date in
                        let dayTasks = store.tasksForDay(date)
                            .filter { !$0.isInbox && !$0.isCompleted && !$0.isAllDay }
                            .sorted { $0.date < $1.date }
                        
                        ZStack(alignment: .top) {
                            Color.clear
                            
                            ForEach(dayTasks) { task in
                                weekTaskCircle(
                                    task: task,
                                    dayStart: cal.startOfDay(for: date),
                                    hourRowHeight: hourRowHeight,
                                    startHour: startHour
                                )
                                .draggable(task.id.uuidString) {
                                    HStack {
                                        Circle().fill(task.taskColor).frame(width: 6, height: 6)
                                        Text(task.title).font(.system(size: 11, weight: .medium))
                                    }
                                    .padding(4)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(theme.cardBackground))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .contentShape(Rectangle())
                        .dropDestination(for: String.self) { items, location in
                            guard let taskID = items.first, let uuid = UUID(uuidString: taskID) else { return false }
                            let minutesFromTop = Double(location.y) / Double(hourRowHeight) * 60.0
                            let totalMinutes = Double(startHour) * 60.0 + minutesFromTop
                            let snapped = max(0, min(24 * 60 - 1, Int(round(totalMinutes / 15.0) * 15.0)))
                            withAnimation(.easeOut(duration: 0.25)) {
                                moveTaskToDateAndTime(taskID: uuid, date: date, hour: snapped / 60, minute: snapped % 60)
                            }
                            return true
                        } isTargeted: { targeted in
                            // Highlight handled by overlay
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(Color.clear, lineWidth: 0)
                        )
                        
                        // Column divider
                        if idx < days.count - 1 {
                            Rectangle()
                                .fill(theme.divider.opacity(0.3))
                                .frame(width: 0.5)
                                .frame(height: CGFloat(endHour - startHour) * hourRowHeight)
                        }
                    }
                }
            }
            .frame(minHeight: CGFloat(endHour - startHour) * hourRowHeight)
        }
        .padding(.leading, 4)
    }
    
    // MARK: - Week Task Block (compact card)
    
    private func weekTaskCircle(task: PlannerTask, dayStart: Date, hourRowHeight: CGFloat, startHour: Int) -> some View {
        let cal = Calendar.current
        let taskHour = cal.component(.hour, from: task.date)
        let taskMinute = cal.component(.minute, from: task.date)
        let rowOffset = CGFloat(taskHour - startHour) + CGFloat(taskMinute) / 60.0
        let yOffset = max(0, rowOffset * hourRowHeight)
        let durationMinutes = task.durationMinutes > 0 ? task.durationMinutes : 60
        let blockHeight = max(22, CGFloat(durationMinutes) / 60.0 * hourRowHeight)
        
        return VStack(alignment: .leading, spacing: 0) {
            Text(task.title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(blockHeight > 40 ? 2 : 1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: blockHeight, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(task.taskColor.opacity(0.85))
        )
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { onEditTask(task) }
        .padding(.horizontal, 1)
        .offset(y: yOffset)
        .accessibilityLabel("\(task.title), \(shortTimeLabel(task.date))")
    }
    
    // MARK: - Month Content (Structured-style calendar grid with task details)
    
    private var monthContent: some View {
        let cal = Calendar.current
        let monthRange = cal.range(of: .day, in: .month, for: selectedDate) ?? 1..<31
        let firstOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: selectedDate))!
        let firstWeekday = cal.component(.weekday, from: firstOfMonth)
        let emptyCells = (firstWeekday - cal.firstWeekday + 7) % 7
        
        let weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        
        return VStack(spacing: 0) {
            // Weekday header row
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(weekdayNames[(i + cal.firstWeekday - 1) % 7])
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)
            
            // Calendar grid
            let totalCells = emptyCells + monthRange.count
            let totalRows = (totalCells + 6) / 7
            
            ForEach(0..<totalRows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let cellIndex = row * 7 + col
                        let dayNumber = cellIndex - emptyCells + 1
                        
                        if cellIndex < emptyCells || dayNumber > monthRange.count {
                            // Empty cell (previous/next month)
                            monthEmptyCell
                        } else if let date = cal.date(byAdding: .day, value: dayNumber - 1, to: firstOfMonth) {
                            monthDayCellStructured(date: date, day: dayNumber)
                        } else {
                            monthEmptyCell
                        }
                    }
                }
            }
            
            Spacer()
        }
    }
    
    private var monthEmptyCell: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 100)
            .overlay(
                Rectangle()
                    .fill(theme.divider.opacity(0.3))
                    .frame(height: 0.5),
                alignment: .top
            )
    }
    
    private func monthDayCellStructured(date: Date, day: Int) -> some View {
        let cal = Calendar.current
        let isToday = cal.isDateInToday(date)
        let isSelected = cal.isDate(date, inSameDayAs: selectedDate)
        let tasks = store.tasksForDay(date).filter { !$0.isInbox && !$0.isCompleted }
            .sorted { $0.date < $1.date }
        
        return VStack(alignment: .leading, spacing: 3) {
            // Day number — tap to switch to day view
            Text("\(day)")
                .font(.system(size: 14, weight: isToday ? .bold : .semibold))
                .foregroundColor(isToday ? .white : (isSelected ? JarvisTheme.accent : theme.textPrimary))
                .frame(width: 26, height: 26)
                .background(
                    Circle()
                        .fill(isToday ? JarvisTheme.accent : Color.clear)
                )
                .frame(maxWidth: .infinity, alignment: .center)
            
            // Task entries — individually tappable & draggable
            ForEach(tasks.prefix(3)) { task in
                monthTaskEntry(task: task)
                    .contentShape(Rectangle())
                    .onTapGesture { onEditTask(task) }
                    .draggable(task.id.uuidString) {
                        HStack {
                            Circle().fill(task.taskColor).frame(width: 6, height: 6)
                            Text(task.title).font(.system(size: 11, weight: .medium))
                        }
                        .padding(4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(theme.cardBackground))
                    }
            }
            
            if tasks.count > 3 {
                Text("+\(tasks.count - 3)")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(theme.textTertiary)
                    .padding(.leading, 2)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 100)
        .background(
            isSelected ? theme.cardBackground : Color.clear
        )
        .overlay(
            Rectangle()
                .fill(theme.divider.opacity(0.3))
                .frame(height: 0.5),
            alignment: .top
        )
        .overlay(
            Rectangle()
                .fill(theme.divider.opacity(0.15))
                .frame(width: 0.5),
            alignment: .trailing
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedDate = date
            withAnimation(.easeInOut(duration: 0.2)) { viewMode = .day }
        }
        .dropDestination(for: String.self) { items, _ in
            guard let taskID = items.first, let uuid = UUID(uuidString: taskID) else { return false }
            withAnimation(.easeOut(duration: 0.25)) {
                moveTaskToDate(uuid, date: date)
            }
            return true
        }
    }
    
    // MARK: - Month Task Entry (colored dot + name, compact)
    
    private func monthTaskEntry(task: PlannerTask) -> some View {
        HStack(spacing: 3) {
            // Colored dot
            Circle()
                .fill(task.taskColor)
                .frame(width: 5, height: 5)
                .fixedSize()
            
            // Task name — full width for readability
            Text(task.title)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)
        }
    }
    
    // MARK: - Helper: short time label for month view (e.g., "8AM", "10PM")
    
    private func shortTimeLabel(_ date: Date) -> String {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: date)
        let minute = cal.component(.minute, from: date)
        let h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let ampm = hour < 12 ? "AM" : "PM"
        if minute == 0 {
            return "\(h12)\(ampm)"
        }
        return "\(h12):\(String(format: "%02d", minute))\(ampm)"
    }
    
    // MARK: - Helper: AM/PM hour label for grid
    
    private func hourLabelAMPM(_ hour: Int) -> String {
        if hour == 0 { return "12AM" }
        if hour == 12 { return "12PM" }
        if hour < 12 { return "\(hour)AM" }
        return "\(hour - 12)PM"
    }
    
    // MARK: - Actions
    
    private func moveDate(by days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDate = newDate
            }
        }
    }
    
    private func getCurrentWeekDays() -> [Date] {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))!
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }
    
    private func moveTaskToDate(_ taskID: UUID, date: Date) {
        guard let task = store.tasks.first(where: { $0.id == taskID }) else { return }
        var updated = task
        updated.isInbox = false
        updated.date = Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: task.date),
                                              minute: Calendar.current.component(.minute, from: task.date),
                                              second: 0, of: date) ?? date
        store.update(updated)
    }
    
    private func moveTaskToDateAndTime(taskID: UUID, date: Date, hour: Int, minute: Int = 0) {
        guard let task = store.tasks.first(where: { $0.id == taskID }) else { return }
        var updated = task
        updated.isInbox = false
        updated.isAllDay = false
        let dayStart = Calendar.current.startOfDay(for: date)
        updated.date = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart) ?? dayStart
        store.update(updated)
    }
}
