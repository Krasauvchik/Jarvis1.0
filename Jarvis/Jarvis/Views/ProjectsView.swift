#if !os(watchOS)
import SwiftUI

// MARK: - Projects View (Phase 3)

struct ProjectsView: View {
    @StateObject private var store = PlannerStore.shared
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showAddProject = false
    @State private var editingProject: Project?
    
    private var theme: JarvisTheme {
        JarvisTheme.current(for: colorScheme)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if store.projects.isEmpty {
                        emptyState
                            .animateOnAppear(delay: 0.1)
                    } else {
                        ForEach(store.projects.filter { !$0.isArchived }) { project in
                            projectCard(project)
                                .animateOnAppear(delay: 0.05)
                        }
                        
                        let archived = store.projects.filter(\.isArchived)
                        if !archived.isEmpty {
                            DisclosureGroup {
                                ForEach(archived) { project in
                                    projectCard(project)
                                }
                            } label: {
                                Text("Архив (\(archived.count))")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Проекты")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAddProject = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(JarvisTheme.accent)
                    }
                }
            }
            .sheet(isPresented: $showAddProject) {
                ProjectEditorSheet(project: nil, theme: theme)
            }
            .sheet(item: $editingProject) { project in
                ProjectEditorSheet(project: project, theme: theme)
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(theme.textTertiary)
            
            Text("Нет проектов")
                .font(.title3.weight(.semibold))
                .foregroundColor(theme.textPrimary)
            
            Text("Группируйте задачи по проектам\nдля лучшей организации")
                .font(.subheadline)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
            
            Button(action: { showAddProject = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Создать проект")
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Capsule().fill(JarvisTheme.accent))
            }
            .buttonStyle(.plain)
            .bounceOnTap()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
    
    // MARK: - Project Card
    
    private func projectCard(_ project: Project) -> some View {
        let progress = store.projectProgress(project.id)
        let progressRate = progress.total > 0 ? Double(progress.completed) / Double(progress.total) : 0
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: project.icon)
                    .font(.system(size: 20))
                    .foregroundColor(project.color)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(project.color.opacity(0.15))
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.headline)
                        .foregroundColor(theme.textPrimary)
                    
                    if !project.description.isEmpty {
                        Text(project.description)
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(progress.completed)/\(progress.total)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(project.color)
                    
                    Text("\(Int(progressRate * 100))%")
                        .font(.system(size: 11))
                        .foregroundColor(theme.textTertiary)
                }
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(project.color.opacity(0.15))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(project.color)
                        .frame(width: geo.size.width * progressRate, height: 6)
                        .animation(.spring(response: 0.5), value: progressRate)
                }
            }
            .frame(height: 6)
            
            // Sub-tasks preview
            let projectTasks = store.tasksForProject(project.id).prefix(3)
            if !projectTasks.isEmpty {
                VStack(spacing: 4) {
                    ForEach(Array(projectTasks), id: \.id) { task in
                        HStack(spacing: 8) {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 14))
                                .foregroundColor(task.isCompleted ? JarvisTheme.accentGreen : theme.textTertiary)
                            
                            Text(task.title)
                                .font(.system(size: 13))
                                .foregroundColor(task.isCompleted ? theme.textTertiary : theme.textPrimary)
                                .strikethrough(task.isCompleted)
                                .lineLimit(1)
                            
                            // Show sub-task count
                            let subCount = store.subTasks(of: task.id).count
                            if subCount > 0 {
                                Text("(\(subCount))")
                                    .font(.system(size: 11))
                                    .foregroundColor(theme.textTertiary)
                            }
                            
                            Spacer()
                        }
                    }
                    
                    let remaining = store.tasksForProject(project.id).count - 3
                    if remaining > 0 {
                        Text("ещё \(remaining)")
                            .font(.system(size: 11))
                            .foregroundColor(theme.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.cardBackground)
                .shadow(color: theme.cardShadow, radius: 4, y: 2)
        )
        .opacity(project.isArchived ? 0.6 : 1)
        .contextMenu {
            Button {
                editingProject = project
            } label: {
                Label("Редактировать", systemImage: "pencil")
            }
            
            Button {
                var updated = project
                updated.isArchived.toggle()
                store.updateProject(updated)
            } label: {
                Label(
                    project.isArchived ? "Разархивировать" : "Архивировать",
                    systemImage: project.isArchived ? "archivebox" : "archivebox.fill"
                )
            }
            
            Divider()
            
            Button(role: .destructive) {
                store.removeProject(project)
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }
}

// MARK: - Project Editor Sheet

struct ProjectEditorSheet: View {
    let project: Project?
    let theme: JarvisTheme
    
    @StateObject private var store = PlannerStore.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var description: String
    @State private var colorIndex: Int
    @State private var icon: String
    
    init(project: Project?, theme: JarvisTheme) {
        self.project = project
        self.theme = theme
        _name = State(initialValue: project?.name ?? "")
        _description = State(initialValue: project?.description ?? "")
        _colorIndex = State(initialValue: project?.colorIndex ?? 0)
        _icon = State(initialValue: project?.icon ?? "folder.fill")
    }
    
    private let projectIcons = [
        "folder.fill", "briefcase.fill", "star.fill", "heart.fill",
        "bolt.fill", "flame.fill", "flag.fill", "bookmark.fill",
        "lightbulb.fill", "graduationcap.fill", "house.fill", "car.fill",
        "gamecontroller.fill", "music.note", "camera.fill", "paintbrush.fill"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Название") {
                    TextField("Название проекта", text: $name)
                }
                
                Section("Описание") {
                    TextField("Описание (опционально)", text: $description)
                }
                
                Section("Цвет") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                        ForEach(0..<JarvisTheme.taskColors.count, id: \.self) { index in
                            Circle()
                                .fill(JarvisTheme.taskColors[index])
                                .frame(width: 30, height: 30)
                                .overlay {
                                    if colorIndex == index {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .onTapGesture { colorIndex = index }
                        }
                    }
                }
                
                Section("Иконка") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                        ForEach(projectIcons, id: \.self) { iconName in
                            Image(systemName: iconName)
                                .font(.system(size: 18))
                                .foregroundColor(icon == iconName ? .white : JarvisTheme.taskColors[colorIndex])
                                .frame(width: 36, height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(icon == iconName ? JarvisTheme.taskColors[colorIndex] : JarvisTheme.taskColors[colorIndex].opacity(0.15))
                                )
                                .onTapGesture { icon = iconName }
                        }
                    }
                }
            }
            .navigationTitle(project == nil ? "Новый проект" : "Редактировать")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        saveProject()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func saveProject() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        if var existing = project {
            existing.name = trimmedName
            existing.description = description
            existing.colorIndex = colorIndex
            existing.icon = icon
            store.updateProject(existing)
        } else {
            let newProject = Project(
                name: trimmedName,
                description: description,
                colorIndex: colorIndex,
                icon: icon
            )
            store.addProject(newProject)
        }
    }
}

// MARK: - Sub-Task List (embeddable in task detail)

struct SubTaskListView: View {
    let parentTaskId: UUID
    @StateObject private var store = PlannerStore.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var newSubTaskTitle = ""
    
    private var theme: JarvisTheme {
        JarvisTheme.current(for: colorScheme)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Подзадачи")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.textPrimary)
                
                Spacer()
                
                let subTasks = store.subTasks(of: parentTaskId)
                let completed = subTasks.filter(\.isCompleted).count
                if !subTasks.isEmpty {
                    Text("\(completed)/\(subTasks.count)")
                        .font(.caption.weight(.medium))
                        .foregroundColor(theme.textTertiary)
                }
            }
            
            ForEach(store.subTasks(of: parentTaskId)) { subTask in
                HStack(spacing: 8) {
                    Button {
                        store.toggleCompletion(task: subTask, onDay: nil)
                    } label: {
                        Image(systemName: subTask.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16))
                            .foregroundColor(subTask.isCompleted ? JarvisTheme.accentGreen : theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    
                    Text(subTask.title)
                        .font(.system(size: 14))
                        .foregroundColor(subTask.isCompleted ? theme.textTertiary : theme.textPrimary)
                        .strikethrough(subTask.isCompleted)
                    
                    Spacer()
                    
                    Button(role: .destructive) {
                        store.delete(subTask)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 2)
            }
            
            // Add sub-task inline
            HStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 16))
                    .foregroundColor(JarvisTheme.accent)
                
                TextField("Добавить подзадачу", text: $newSubTaskTitle)
                    .font(.system(size: 14))
                    .textFieldStyle(.plain)
                    .onSubmit {
                        addSubTask()
                    }
                
                if !newSubTaskTitle.isEmpty {
                    Button(action: addSubTask) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(JarvisTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private func addSubTask() {
        let title = newSubTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        store.addSubTask(title: title, parentId: parentTaskId)
        newSubTaskTitle = ""
    }
}

#endif
