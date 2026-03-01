import SwiftUI

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
    
    var body: some View {
        VStack(spacing: 0) {
            // Date header
            HStack {
                Text(selectedDate.formatted(.dateTime.day().month(.wide).year()))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                Spacer()
                
                dateNavigation
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // Week strip
            weekStripLarge
            
            Divider().background(theme.divider)
            
            // Timeline content
            ScrollView {
                timelineContent
            }
        }
        .background(theme.background)
    }
    
    // MARK: - Date Navigation
    
    private var dateNavigation: some View {
        HStack(spacing: 8) {
            Button(action: { moveDate(by: -1) }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(theme.cardBackground))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Предыдущий день")
            
            Button(action: { selectedDate = Date() }) {
                Text("Сегодня")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(JarvisTheme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(theme.cardBackground))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Вернуться к сегодня")
            
            Button(action: { moveDate(by: 1) }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(theme.cardBackground))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Следующий день")
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
                    .offset(y: isDragging ? timelineDragOffset.height : 0)
                    .zIndex(isDragging ? 100 : 0)
                    .contentShape(Rectangle())
                    .onTapGesture { onEditTask(task) }
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 8)
                            .onChanged { value in
                                if timelineDraggingTaskId == nil {
                                    timelineDraggingTaskId = task.id
                                }
                                if timelineDraggingTaskId == task.id {
                                    timelineDragOffset = CGSize(width: 0, height: value.translation.height)
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
                            }
                    )
                    .dropDestination(for: String.self) { items, location in
                        guard let taskID = items.first, let uuid = UUID(uuidString: taskID) else { return false }
                        let blockFrame = timelineBlockFrames[task.id] ?? .zero
                        let timelineY = blockFrame.minY + location.y
                        let contentY = timelineY - timelineTopPadding
                        let rowIndex = max(0, Int(contentY / hourRowHeight))
                        let hour = max(0, min(timelineStartHour + rowIndex, 24))
                        withAnimation(.easeOut(duration: 0.25)) {
                            moveTaskToDateAndTime(taskID: uuid, date: selectedDate, hour: hour % 24, minute: 0)
                        }
                        return true
                    }
                    .background(
                        GeometryReader { g in
                            Color.clear.preference(key: TimelineBlockFramesKey.self, value: [task.id: g.frame(in: .named("timeline"))])
                        }
                    )
                    .draggable(task.id.uuidString) {
                        HStack {
                            Circle().fill(task.taskColor).frame(width: 8, height: 8)
                            Text(task.title).font(.system(size: 14, weight: .medium))
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(theme.cardBackground))
                        .scaleEffect(1.08)
                    }
                    .padding(.leading, 68)
                    .padding(.trailing, 20)
                }
            }
        }
        .coordinateSpace(name: "timeline")
        .onPreferenceChange(TimelineBlockFramesKey.self) { timelineBlockFrames = $0 }
        .frame(minHeight: CGFloat(timelineEndHour - timelineStartHour) * hourRowHeight)
        .animation(.easeOut(duration: 0.25), value: dayTasks.map { "\($0.id)\($0.date.timeIntervalSince1970)" })
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
