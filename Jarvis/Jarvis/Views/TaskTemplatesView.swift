import SwiftUI

// MARK: - Task Templates View

/// Lets the user browse built-in & custom task templates, create tasks from them,
/// and manage the template library.
struct TaskTemplatesView: View {
    @ObservedObject var store: PlannerStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTemplate: TaskTemplate?
    @State private var showCreateSheet = false
    @State private var targetDate = Date()
    @State private var sendToInbox = false
    
    private var theme: JarvisTheme {
        JarvisTheme.current(for: ThemeManager.shared.currentTheme.colorScheme ?? .light)
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Built-in templates
                Section {
                    ForEach(TaskTemplate.builtIn) { tmpl in
                        templateRow(tmpl)
                    }
                } header: {
                    Text(L10n.builtInTemplates)
                }
                
                // Custom templates
                if !customTemplates.isEmpty {
                    Section {
                        ForEach(customTemplates) { tmpl in
                            templateRow(tmpl)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let tmpl = customTemplates[index]
                                store.templates.removeAll { $0.id == tmpl.id }
                            }
                        }
                    } header: {
                        Text(L10n.customTemplates)
                    }
                }
                
                // Create new template
                Section {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Label(L10n.createTemplate, systemImage: "plus.rectangle.on.folder")
                    }
                }
            }
            .navigationTitle(L10n.templates)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) { dismiss() }
                }
            }
            .sheet(item: $selectedTemplate) { tmpl in
                instantiateSheet(tmpl)
            }
            .sheet(isPresented: $showCreateSheet) {
                createTemplateSheet
            }
        }
    }
    
    // MARK: - Helpers
    
    private var customTemplates: [TaskTemplate] {
        store.templates.filter { tmpl in
            !TaskTemplate.builtIn.contains(where: { $0.id == tmpl.id })
        }
    }
    
    private func templateRow(_ tmpl: TaskTemplate) -> some View {
        Button {
            selectedTemplate = tmpl
        } label: {
            HStack(spacing: 12) {
                Image(systemName: tmpl.icon)
                    .font(.system(size: 18))
                    .foregroundColor(JarvisTheme.taskColors[tmpl.colorIndex % JarvisTheme.taskColors.count])
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(JarvisTheme.taskColors[tmpl.colorIndex % JarvisTheme.taskColors.count].opacity(0.12))
                    )
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(tmpl.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                    
                    HStack(spacing: 8) {
                        Label("\(tmpl.durationMinutes) \(L10n.minutesShort)", systemImage: "clock")
                            .font(.system(size: 12))
                            .foregroundColor(theme.textTertiary)
                        
                        if !tmpl.subtaskTitles.isEmpty {
                            Label("\(tmpl.subtaskTitles.count) \(L10n.subtasks)", systemImage: "list.bullet")
                                .font(.system(size: 12))
                                .foregroundColor(theme.textTertiary)
                        }
                        
                        Text(tmpl.priority.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(tmpl.priority.color)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(theme.textTertiary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Instantiate Sheet
    
    private func instantiateSheet(_ tmpl: TaskTemplate) -> some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: tmpl.icon)
                            .foregroundColor(JarvisTheme.taskColors[tmpl.colorIndex % JarvisTheme.taskColors.count])
                        Text(tmpl.name)
                            .font(.headline)
                    }
                    if !tmpl.notes.isEmpty {
                        Text(tmpl.notes)
                            .font(.subheadline)
                            .foregroundColor(theme.textSecondary)
                    }
                } header: {
                    Text(L10n.templates)
                }
                
                Section {
                    DatePicker(L10n.dateTimeField, selection: $targetDate, displayedComponents: [.date, .hourAndMinute])
                    Toggle(L10n.inboxToggle, isOn: $sendToInbox)
                } header: {
                    Text(L10n.scheduleAction)
                }
                
                if !tmpl.subtaskTitles.isEmpty {
                    Section {
                        ForEach(tmpl.subtaskTitles, id: \.self) { sub in
                            Label(sub, systemImage: "circle")
                                .foregroundColor(theme.textSecondary)
                        }
                    } header: {
                        Text(L10n.subtasks)
                    }
                }
            }
            .navigationTitle(L10n.createFromTemplate)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { selectedTemplate = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.addAction) {
                        let (parent, subs) = tmpl.instantiate(date: targetDate, isInbox: sendToInbox)
                        store.add(parent)
                        for sub in subs {
                            store.add(sub)
                        }
                        selectedTemplate = nil
                    }
                }
            }
        }
    }
    
    // MARK: - Create Template Sheet
    
    private var createTemplateSheet: some View {
        CreateTemplateSheet(store: store, onDismiss: { showCreateSheet = false })
    }
}

// MARK: - Create Template Sheet

struct CreateTemplateSheet: View {
    @ObservedObject var store: PlannerStore
    let onDismiss: () -> Void
    
    @State private var name = ""
    @State private var title = ""
    @State private var notes = ""
    @State private var durationMinutes = 60
    @State private var priority: TaskPriority = .medium
    @State private var colorIndex = 4
    @State private var icon = "doc.text.fill"
    @State private var subtaskTitles: [String] = []
    @State private var newSubtaskTitle = ""
    
    private var theme: JarvisTheme {
        JarvisTheme.current(for: ThemeManager.shared.currentTheme.colorScheme ?? .light)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.nameField, text: $name)
                    TextField(L10n.taskName, text: $title)
                    TextField(L10n.notesField, text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text(L10n.templateInfo)
                }
                
                Section {
                    Stepper(value: $durationMinutes, in: 5...480, step: 15) {
                        Text("\(L10n.durationField): \(durationMinutes) \(L10n.minutesShort)")
                    }
                    Picker(L10n.prioritySection, selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                } header: {
                    Text(L10n.settingsAppearance)
                }
                
                Section {
                    ForEach(subtaskTitles.indices, id: \.self) { i in
                        HStack {
                            Image(systemName: "circle")
                                .foregroundColor(theme.textTertiary)
                            Text(subtaskTitles[i])
                            Spacer()
                            Button {
                                subtaskTitles.remove(at: i)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    HStack {
                        TextField(L10n.addSubtask, text: $newSubtaskTitle)
                            .onSubmit {
                                addSubtask()
                            }
                        Button {
                            addSubtask()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(JarvisTheme.accent)
                        }
                        .buttonStyle(.plain)
                        .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text(L10n.subtasks)
                }
            }
            .navigationTitle(L10n.createTemplate)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.addAction) {
                        let template = TaskTemplate(
                            name: name.isEmpty ? title : name,
                            title: title,
                            notes: notes,
                            durationMinutes: durationMinutes,
                            priority: priority,
                            colorIndex: colorIndex,
                            icon: icon,
                            subtaskTitles: subtaskTitles
                        )
                        store.templates.append(template)
                        onDismiss()
                    }
                    .disabled(name.isEmpty && title.isEmpty)
                }
            }
        }
    }
    
    private func addSubtask() {
        let trimmed = newSubtaskTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        subtaskTitles.append(trimmed)
        newSubtaskTitle = ""
    }
}
