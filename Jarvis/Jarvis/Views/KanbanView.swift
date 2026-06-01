import SwiftUI

// MARK: - Kanban Board View

/// Displays tasks in a three-column kanban board: To Do → In Progress → Done.
/// Tasks can be dragged between columns. Uses existing PlannerStore for persistence.
struct KanbanView: View {
    @ObservedObject var store: PlannerStore
    @State private var editingTask: PlannerTask?
    @State private var showAddTask = false
    @State private var draggedTask: PlannerTask?
    
    private var theme: JarvisTheme {
        JarvisTheme.current(for: ThemeManager.shared.currentTheme.colorScheme ?? .light)
    }
    
    // MARK: - Column Definitions
    
    enum KanbanColumn: String, CaseIterable, Identifiable {
        case todo = "todo"
        case inProgress = "in_progress"
        case done = "done"
        
        var id: String { rawValue }
        
        var localizedName: String {
            switch self {
            case .todo: return L10n.kanbanToDo
            case .inProgress: return L10n.kanbanInProgress
            case .done: return L10n.kanbanDone
            }
        }
        
        var icon: String {
            switch self {
            case .todo: return "circle"
            case .inProgress: return "arrow.right.circle.fill"
            case .done: return "checkmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .todo: return JarvisTheme.accentBlue
            case .inProgress: return JarvisTheme.accentOrange
            case .done: return JarvisTheme.accentGreen
            }
        }
    }
    
    // MARK: - Data Filtering
    
    /// Tasks that are not completed and not in Inbox → "To Do"
    private var todoTasks: [PlannerTask] {
        store.tasks.filter { !$0.isCompleted && !$0.isInbox && $0.notes.lowercased() != "in_progress" && !isInProgress($0) }
            .sorted { ($0.priority.sortOrder, $0.date) < ($1.priority.sortOrder, $1.date) }
    }
    
    /// Tasks tagged as "in progress" (using notes marker or custom logic)
    private var inProgressTasks: [PlannerTask] {
        store.tasks.filter { !$0.isCompleted && isInProgress($0) }
            .sorted { ($0.priority.sortOrder, $0.date) < ($1.priority.sortOrder, $1.date) }
    }
    
    /// Completed tasks
    private var doneTasks: [PlannerTask] {
        store.tasks.filter { $0.isCompleted }
            .sorted { ($0.completedAt ?? $0.modifiedAt) > ($1.completedAt ?? $1.modifiedAt) }
    }
    
    private func isInProgress(_ task: PlannerTask) -> Bool {
        // Convention: tasks with a comment containing "[IN_PROGRESS]" marker
        // or tasks that have time logged but are not completed
        task.spentMinutes > 0 && !task.isCompleted
    }
    
    private func tasks(for column: KanbanColumn) -> [PlannerTask] {
        switch column {
        case .todo: return todoTasks
        case .inProgress: return inProgressTasks
        case .done: return doneTasks
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "rectangle.split.3x1.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(JarvisTheme.accent)
                Text(L10n.kanbanBoard)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Button(action: { showAddTask = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(JarvisTheme.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            
            Divider().background(theme.divider)
            
            // Columns
            #if os(watchOS)
            Text(L10n.unavailableWatchOS)
                .foregroundColor(theme.textSecondary)
            #else
            GeometryReader { geo in
                HStack(spacing: 12) {
                    ForEach(KanbanColumn.allCases) { column in
                        kanbanColumn(column, width: (geo.size.width - 48) / 3)
                    }
                }
                .padding(12)
            }
            #endif
        }
        .background(theme.background)
        .sheet(item: $editingTask) { task in
            EditTaskSheet(task: task, theme: theme)
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskSheet(date: Date(), theme: theme)
        }
    }
    
    // MARK: - Column View
    
    #if !os(watchOS)
    private func kanbanColumn(_ column: KanbanColumn, width: CGFloat) -> some View {
        let columnTasks = tasks(for: column)
        return VStack(spacing: 0) {
            // Column Header
            HStack(spacing: 8) {
                Image(systemName: column.icon)
                    .foregroundColor(column.color)
                    .font(.system(size: 14, weight: .semibold))
                Text(column.localizedName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Text("\(columnTasks.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(theme.cardBackground))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(column.color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            // Task Cards
            ScrollView {
                LazyVStack(spacing: 8) {
                    if columnTasks.isEmpty {
                        Text(L10n.noTasks)
                            .font(.system(size: 13))
                            .foregroundColor(theme.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                    } else {
                        ForEach(columnTasks) { task in
                            kanbanCard(task, column: column)
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, 4)
            }
        }
        .frame(width: width)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.cardBackground.opacity(0.5))
        )
        .dropDestination(for: String.self) { items, _ in
            guard let taskIDStr = items.first, let taskID = UUID(uuidString: taskIDStr) else { return false }
            moveTask(taskID, to: column)
            return true
        }
    }
    
    private func kanbanCard(_ task: PlannerTask, column: KanbanColumn) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(task.taskColor)
                    .frame(width: 8, height: 8)
                
                Text(task.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(2)
                    .strikethrough(task.isCompleted)
                
                Spacer(minLength: 0)
            }
            
            if !task.notes.isEmpty {
                Text(task.notes)
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(2)
            }
            
            HStack(spacing: 8) {
                // Priority badge
                HStack(spacing: 3) {
                    Image(systemName: task.priority.icon)
                        .font(.system(size: 9))
                    Text(task.priority.displayName)
                        .font(.system(size: 10))
                }
                .foregroundColor(task.priority.color)
                
                // Time spent
                if task.spentMinutes > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text(L10n.minutesShortValue(task.spentMinutes))
                            .font(.system(size: 10))
                    }
                    .foregroundColor(theme.textTertiary)
                }
                
                // Subtasks count
                let subtaskCount = store.tasks.filter { $0.parentTaskId == task.id }.count
                if subtaskCount > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 9))
                        Text("\(subtaskCount)")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(theme.textTertiary)
                }
                
                // Comments count
                if !task.comments.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 9))
                        Text("\(task.comments.count)")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(theme.textTertiary)
                }
                
                Spacer()
                
                // Date
                Text(task.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 10))
                    .foregroundColor(theme.textTertiary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.cardBackground)
                .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
        )
        .onTapGesture { editingTask = task }
        .draggable(task.id.uuidString)
        .contextMenu {
            Button { moveTask(task.id, to: .todo) } label: {
                Label(L10n.kanbanToDo, systemImage: "circle")
            }
            Button { moveTask(task.id, to: .inProgress) } label: {
                Label(L10n.kanbanInProgress, systemImage: "arrow.right.circle.fill")
            }
            Button { moveTask(task.id, to: .done) } label: {
                Label(L10n.kanbanDone, systemImage: "checkmark.circle.fill")
            }
            Divider()
            Button(role: .destructive) { store.delete(task) } label: {
                Label(L10n.deleteTask, systemImage: "trash")
            }
        }
    }
    #endif
    
    // MARK: - Move Task Between Columns
    
    private func moveTask(_ taskID: UUID, to column: KanbanColumn) {
        guard var task = store.tasks.first(where: { $0.id == taskID }) else { return }
        switch column {
        case .todo:
            task.isCompleted = false
            task.completedAt = nil
            // Remove time-spent marker if needed (keep actual time)
        case .inProgress:
            task.isCompleted = false
            task.completedAt = nil
            // Mark as in-progress by adding minimal spent time if zero
            if task.spentMinutes == 0 {
                task.spentMinutes = 1 // sentinel: "started"
            }
        case .done:
            task.isCompleted = true
            task.completedAt = Date()
        }
        store.update(task)
    }
}
