import SwiftUI
#if os(iOS)
import UniformTypeIdentifiers
#endif

// MARK: - Identifiable URL Helper

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Settings Content

struct SettingsContent: View {
    let theme: JarvisTheme
    @Binding var showSleepCalculator: Bool
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var store = PlannerStore.shared
    @StateObject private var cloudSync = CloudSync.shared
    @ObservedObject private var aiManager = DependencyContainer.shared.aiManager
    @State private var shareURL: IdentifiableURL?
    @State private var showImportPicker = false
    @State private var importMessage: String?
    @State private var showImportResult = false
    @State private var importMerge = true
    @State private var showDeleteCompletedConfirm = false
    @State private var showDeleteAllConfirm = false
    @StateObject private var calendarSync = CalendarSyncService.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                settingsSection(title: L10n.settingsSync, icon: "icloud.fill") {
                    HStack {
                        Label("iCloud", systemImage: "icloud")
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                        if cloudSync.isSyncing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if let date = cloudSync.lastSyncDate {
                            Text(date.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 13))
                                .foregroundColor(theme.textSecondary)
                        } else {
                            Text(L10n.settingsSyncEnabled)
                                .font(.system(size: 13))
                                .foregroundColor(theme.textSecondary)
                        }
                    }
                    .padding(.vertical, 8)
                    if let err = cloudSync.syncError {
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundColor(JarvisTheme.accentOrange)
                            .padding(.vertical, 4)
                    }
                    Button(action: { cloudSync.forceSync() }) {
                        Label(L10n.settingsSyncNow, systemImage: "arrow.clockwise")
                            .foregroundColor(JarvisTheme.accent)
                    }
                    .buttonStyle(.plain)
                    .bounceOnTap()
                    .disabled(cloudSync.isSyncing)
                    .padding(.vertical, 4)
                }
                
                settingsSection(title: L10n.settingsAppearance, icon: "paintbrush.fill") {
                    ForEach(ThemeMode.allCases, id: \.self) { mode in
                        themeRow(mode: mode)
                    }
                    settingsToggle(
                        title: L10n.settingsHoverZoom,
                        icon: "arrow.up.left.and.arrow.down.right",
                        isOn: Binding(
                            get: { UserDefaults.standard.object(forKey: Config.Storage.dockMagnificationKey) as? Bool ?? true },
                            set: { UserDefaults.standard.set($0, forKey: Config.Storage.dockMagnificationKey) }
                        )
                    )
                    Text(L10n.settingsHoverZoomDesc)
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)
                        .padding(.top, 2)
                }
                
                settingsSection(title: L10n.settingsAISection, icon: "brain.head.profile") {
                    Picker(L10n.settingsAIModel, selection: Binding(
                        get: { aiManager.selectedModel },
                        set: { aiManager.selectedModel = $0 }
                    )) {
                        ForEach(AIModel.allCases) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                    .foregroundColor(theme.textPrimary)
                    Text(L10n.settingsAIModelDesc)
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)
                        .padding(.top, 4)
                }
                
                settingsSection(title: L10n.settingsHealth, icon: "heart.fill") {
                    Button(action: { showSleepCalculator = true }) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(JarvisTheme.accentPurple.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "moon.zzz.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(JarvisTheme.accentPurple)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.settingsSleepCalc)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(theme.textPrimary)
                                Text(L10n.settingsSleepCalcTime)
                                    .font(.system(size: 13))
                                    .foregroundColor(theme.textSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(theme.textTertiary)
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .bounceOnTap()
                }
                
                settingsSection(title: L10n.settingsCalendar, icon: "calendar") {
                    Button(action: {
                        Task {
                            _ = await calendarSync.requestAccess()
                        }
                    }) {
                        HStack {
                            Label(L10n.settingsCalendarAccess, systemImage: "calendar.badge.plus")
                                .foregroundColor(theme.textPrimary)
                            Spacer()
                            if calendarSync.isAuthorizedForCalendar {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(JarvisTheme.accentGreen)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .bounceOnTap()
                    Toggle(isOn: Binding(
                        get: { calendarSync.syncToCalendarEnabled },
                        set: { calendarSync.setSyncToCalendarEnabled($0) }
                    )) {
                        Label(L10n.settingsCalendarSync, systemImage: "calendar")
                            .foregroundColor(theme.textPrimary)
                    }
                    .padding(.vertical, 4)
                }
                
                settingsSection(title: L10n.settingsAISkills, icon: "cpu") {
                    Text(L10n.settingsAISkillsDesc)
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)
                        .padding(.bottom, 4)
                    settingsToggle(
                        title: L10n.settingsCalendar,
                        icon: "calendar",
                        isOn: Binding(
                            get: { UserDefaults.standard.object(forKey: Config.Storage.skillCalendarKey) as? Bool ?? true },
                            set: { UserDefaults.standard.set($0, forKey: Config.Storage.skillCalendarKey) }
                        )
                    )
                    settingsToggle(
                        title: L10n.mailSectionLabel,
                        icon: "envelope",
                        isOn: Binding(
                            get: { UserDefaults.standard.object(forKey: Config.Storage.skillMailKey) as? Bool ?? true },
                            set: { UserDefaults.standard.set($0, forKey: Config.Storage.skillMailKey) }
                        )
                    )
                    settingsToggle(
                        title: L10n.deepAnalysis,
                        icon: "brain",
                        isOn: Binding(
                            get: { UserDefaults.standard.object(forKey: Config.Storage.skillDeepAnalysisKey) as? Bool ?? true },
                            set: { UserDefaults.standard.set($0, forKey: Config.Storage.skillDeepAnalysisKey) }
                        )
                    )
                    settingsToggle(
                        title: L10n.settingsVoiceInput,
                        icon: "mic.fill",
                        isOn: Binding(
                            get: { UserDefaults.standard.object(forKey: Config.Storage.skillVoiceKey) as? Bool ?? true },
                            set: { UserDefaults.standard.set($0, forKey: Config.Storage.skillVoiceKey) }
                        )
                    )
                }
                
                settingsSection(title: L10n.settingsNotifications, icon: "bell.badge.fill") {
                    settingsToggle(
                        title: L10n.settingsReminders,
                        icon: "bell.fill",
                        isOn: Binding(
                            get: { UserDefaults.standard.object(forKey: "jarvis_notifications_enabled") as? Bool ?? true },
                            set: { UserDefaults.standard.set($0, forKey: "jarvis_notifications_enabled") }
                        )
                    )
                    settingsToggle(
                        title: L10n.settingsSound,
                        icon: "speaker.wave.2.fill",
                        isOn: Binding(
                            get: { UserDefaults.standard.object(forKey: "jarvis_notification_sound") as? Bool ?? true },
                            set: { UserDefaults.standard.set($0, forKey: "jarvis_notification_sound") }
                        )
                    )
                }
                
                settingsSection(title: L10n.settingsStats, icon: "chart.bar.fill") {
                    statsRow(title: L10n.settingsTotalTasks, icon: "list.bullet", value: "\(store.tasks.count)", color: JarvisTheme.accent)
                    statsRow(title: L10n.settingsCompletedTasks, icon: "checkmark.circle", value: "\(store.tasks.filter { $0.isCompleted }.count)", color: JarvisTheme.accentGreen)
                    statsRow(title: L10n.settingsInInbox, icon: "tray", value: "\(store.tasks.filter { $0.isInbox && !$0.isCompleted }.count)", color: JarvisTheme.accentOrange)
                }
                
                settingsSection(title: L10n.settingsCategoryTags, icon: "folder.fill") {
                    NavigationLink(destination: CategoriesTagsManageView(theme: theme)) {
                        HStack {
                            Label(L10n.settingsManageCategoryTags, systemImage: "tag.fill")
                                .foregroundColor(theme.textPrimary)
                            Spacer()
                            Text("\(store.categories.count) / \(store.tags.count)")
                                .foregroundColor(theme.textSecondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                settingsSection(title: L10n.settingsData, icon: "externaldrive.fill") {
                    Button(action: {
                        if let url = ExportImport.createExportURL(store: store) {
                            shareURL = IdentifiableURL(url: url)
                        }
                    }) {
                        HStack {
                            Label(L10n.settingsExport, systemImage: "square.and.arrow.up")
                                .foregroundColor(theme.textPrimary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .bounceOnTap()
                    
                    Button(action: { showImportPicker = true }) {
                        HStack {
                            Label(L10n.settingsImport, systemImage: "square.and.arrow.down")
                                .foregroundColor(theme.textPrimary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .bounceOnTap()
                    #if os(iOS)
                    .fileImporter(
                        isPresented: $showImportPicker,
                        allowedContentTypes: [.json],
                        allowsMultipleSelection: false
                    ) { result in
                        Task { @MainActor in
                            switch result {
                            case .success(let urls):
                                guard let url = urls.first else { return }
                                guard url.startAccessingSecurityScopedResource() else {
                                    importMessage = L10n.settingsNoFileAccess
                                    showImportResult = true
                                    return
                                }
                                defer { url.stopAccessingSecurityScopedResource() }
                                importMessage = ExportImport.importFromURL(url, store: store, merge: importMerge)
                                showImportResult = true
                            case .failure:
                                importMessage = L10n.settingsFileError
                                showImportResult = true
                            }
                        }
                    }
                    #endif
                    
                    Button(action: { showDeleteCompletedConfirm = true }) {
                        HStack {
                            Label(L10n.settingsClearCompleted, systemImage: "trash")
                                .foregroundColor(JarvisTheme.accentOrange)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .bounceOnTap()
                    .disabled(store.tasks.filter(\.isCompleted).isEmpty)
                    
                    Button(action: { showDeleteAllConfirm = true }) {
                        HStack {
                            Label(L10n.settingsDeleteAll, systemImage: "trash.fill")
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .bounceOnTap()
                    .disabled(store.tasks.isEmpty)
                }
                .sheet(item: $shareURL) { item in
                    #if os(iOS)
                    ShareSheetView(items: [item.url])
                    #else
                    EmptyView()
                    #endif
                }
                .alert(L10n.settingsImportTitle, isPresented: $showImportResult) {
                    Button("OK", role: .cancel) { }
                } message: {
                    if let msg = importMessage { Text(msg) }
                }
                
                settingsSection(title: L10n.settingsAbout, icon: "info.circle.fill") {
                    HStack {
                        Label(L10n.settingsVersion, systemImage: "info.circle")
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                        Text(Bundle.main.appVersion)
                            .foregroundColor(theme.textSecondary)
                    }
                    .padding(.vertical, 4)
                    
                    HStack {
                        Label(L10n.settingsBuild, systemImage: "hammer")
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                        Text(Bundle.main.buildNumber)
                            .foregroundColor(theme.textSecondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
        }
        .background(theme.background)
        .confirmationDialog(L10n.settingsDeleteCompletedConfirm, isPresented: $showDeleteCompletedConfirm, titleVisibility: .visible) {
            Button(L10n.deleteAction, role: .destructive) {
                NotificationManager.shared.cancelAll()
                store.removeCompleted()
            }
            Button(L10n.cancel, role: .cancel) { }
        } message: {
            Text(L10n.settingsDeleteCompletedDesc)
        }
        .confirmationDialog(L10n.settingsDeleteAllConfirm, isPresented: $showDeleteAllConfirm, titleVisibility: .visible) {
            Button(L10n.deleteAllAction, role: .destructive) {
                NotificationManager.shared.cancelAll()
                store.removeAll()
            }
            Button(L10n.cancel, role: .cancel) { }
        } message: {
            Text(L10n.settingsDeleteAllDesc)
        }
    }
    
    private func settingsSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textSecondary)
            
            VStack(spacing: 0) {
                content()
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBackground))
        }
    }
    
    private func themeRow(mode: ThemeMode) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                themeManager.currentTheme = mode
            }
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(themeBackgroundColor(for: mode))
                        .frame(width: 44, height: 44)
                    Image(systemName: themeIcon(for: mode))
                        .font(.system(size: 20))
                        .foregroundColor(themeIconColor(for: mode))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.displayName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.textPrimary)
                    Text(themeDescription(for: mode))
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSecondary)
                }
                
                Spacer()
                
                if themeManager.currentTheme == mode {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(JarvisTheme.accent)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
    
    private func settingsToggle(title: String, icon: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label(title, systemImage: icon)
                .foregroundColor(theme.textPrimary)
        }
        .padding(.vertical, 4)
    }
    
    private func statsRow(title: String, icon: String, value: String, color: Color) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .foregroundColor(theme.textPrimary)
            Spacer()
            Text(value)
                .foregroundColor(color)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }
    
    private func themeIcon(for mode: ThemeMode) -> String {
        switch mode {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }
    
    private func themeBackgroundColor(for mode: ThemeMode) -> Color {
        switch mode {
        case .light: return Color(red: 1.0, green: 0.95, blue: 0.8)
        case .dark: return Color(red: 0.15, green: 0.15, blue: 0.2)
        case .system: return Color(red: 0.5, green: 0.5, blue: 0.55)
        }
    }
    
    private func themeIconColor(for mode: ThemeMode) -> Color {
        switch mode {
        case .light: return Color.orange
        case .dark: return Color.purple
        case .system: return Color.white
        }
    }
    
    private func themeDescription(for mode: ThemeMode) -> String {
        switch mode {
        case .light: return L10n.settingsThemeLight
        case .dark: return L10n.settingsThemeDark
        case .system: return L10n.settingsThemeSystem
        }
    }
}

// MARK: - Categories & Tags Management

struct CategoriesTagsManageView: View {
    let theme: JarvisTheme
    @StateObject private var store = PlannerStore.shared
    @State private var showAddCategory = false
    @State private var showAddTag = false
    @State private var editingCategory: TaskCategory?
    @State private var editingTag: TaskTag?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                categoriesCard
                    .animateOnAppear(delay: 0)
                tagsCard
                    .animateOnAppear(delay: 0.08)
            }
            .padding()
        }
        .background(theme.background)
        .navigationTitle(L10n.settingsCategoryTags)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showAddCategory) {
            AddCategorySheet(theme: theme, category: nil)
        }
        .sheet(item: $editingCategory) { cat in
            AddCategorySheet(theme: theme, category: cat)
        }
        .sheet(isPresented: $showAddTag) {
            AddTagSheet(theme: theme, tag: nil)
        }
        .sheet(item: $editingTag) { tag in
            AddTagSheet(theme: theme, tag: tag)
        }
    }

    private var categoriesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.categoriesTitle, systemImage: "folder.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textSecondary)
            VStack(spacing: 0) {
                ForEach(store.categories) { cat in
                    HStack(spacing: 12) {
                        Button(action: { editingCategory = cat }) {
                            HStack(spacing: 12) {
                                Image(systemName: cat.icon)
                                    .foregroundColor(cat.color)
                                    .frame(width: 28)
                                Text(cat.name)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(theme.textPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .bounceOnTap()
                        Button(action: { store.removeCategory(cat) }) {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundColor(theme.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(L10n.deleteAction) \(cat.name)")
                        .bounceOnTap()
                    }
                    .padding(.vertical, 8)
                }
                Button(action: { showAddCategory = true }) {
                    Label(L10n.addCategoryAction, systemImage: "plus.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(JarvisTheme.accent)
                }
                .bounceOnTap()
                .padding(.top, 8)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBackground))
        }
    }

    private var tagsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.tagsTitle, systemImage: "tag.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textSecondary)
            VStack(spacing: 0) {
                ForEach(store.tags) { tag in
                    HStack(spacing: 12) {
                        Button(action: { editingTag = tag }) {
                            HStack(spacing: 12) {
                                Circle().fill(tag.color).frame(width: 10, height: 10)
                                Text(tag.name)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(theme.textPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .bounceOnTap()
                        Button(action: { store.removeTag(tag) }) {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundColor(theme.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(L10n.deleteAction) \(tag.name)")
                        .bounceOnTap()
                    }
                    .padding(.vertical, 8)
                }
                Button(action: { showAddTag = true }) {
                    Label(L10n.addTagAction, systemImage: "plus.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(JarvisTheme.accent)
                }
                .bounceOnTap()
                .padding(.top, 8)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBackground))
        }
    }
}

// MARK: - Add Category Sheet

struct AddCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = PlannerStore.shared
    let theme: JarvisTheme
    let category: TaskCategory?
    @State private var name: String = ""
    @State private var colorIndex: Int = 0
    @State private var icon: String = "folder.fill"

    var body: some View {
        NavigationStack {
            Form {
                TextField(L10n.nameField, text: $name)
                Section(L10n.colorSection) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<JarvisTheme.taskColors.count, id: \.self) { i in
                                Circle()
                                    .fill(JarvisTheme.taskColors[i])
                                    .frame(width: 36, height: 36)
                                    .overlay(colorIndex == i ? Circle().stroke(theme.textPrimary, lineWidth: 3) : nil)
                                    .onTapGesture { colorIndex = i }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                Section(L10n.iconSection) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(TaskIcon.allCases, id: \.rawValue) { taskIcon in
                                Image(systemName: taskIcon.systemName)
                                    .font(.system(size: 20))
                                    .foregroundColor(icon == taskIcon.rawValue ? JarvisTheme.taskColors[colorIndex] : theme.textSecondary)
                                    .frame(width: 44, height: 44)
                                    .background(Circle().fill(icon == taskIcon.rawValue ? JarvisTheme.taskColors[colorIndex].opacity(0.2) : Color.clear))
                                    .onTapGesture { icon = taskIcon.rawValue }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.background)
            .navigationTitle(category == nil ? L10n.newCategoryTitle : L10n.editAction)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) {
                        if let cat = category {
                            var updated = cat
                            updated.name = name
                            updated.colorIndex = colorIndex
                            updated.icon = icon
                            store.updateCategory(updated)
                        } else {
                            store.addCategory(TaskCategory(name: name, colorIndex: colorIndex, icon: icon))
                        }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let cat = category {
                    name = cat.name
                    colorIndex = cat.colorIndex
                    icon = cat.icon
                }
            }
        }
    }
}

// MARK: - Add Tag Sheet

struct AddTagSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = PlannerStore.shared
    let theme: JarvisTheme
    let tag: TaskTag?
    @State private var name: String = ""
    @State private var colorIndex: Int = 0

    var body: some View {
        NavigationStack {
            Form {
                TextField(L10n.tagNameField, text: $name)
                Section(L10n.colorSection) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<JarvisTheme.taskColors.count, id: \.self) { i in
                                Circle()
                                    .fill(JarvisTheme.taskColors[i])
                                    .frame(width: 36, height: 36)
                                    .overlay(colorIndex == i ? Circle().stroke(theme.textPrimary, lineWidth: 3) : nil)
                                    .onTapGesture { colorIndex = i }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.background)
            .navigationTitle(tag == nil ? L10n.newTagTitle : L10n.editTagTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) {
                        if let t = tag {
                            var updated = t
                            updated.name = name
                            updated.colorIndex = colorIndex
                            store.updateTag(updated)
                        } else {
                            store.addTag(TaskTag(name: name, colorIndex: colorIndex))
                        }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let t = tag {
                    name = t.name
                    colorIndex = t.colorIndex
                }
            }
        }
    }
}

// MARK: - Settings Sheet

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showSleepCalculator = false
    @State private var selectedSettingsTab: SettingsTab = .account
    let theme: JarvisTheme
    
    var body: some View {
        NavigationStack {
            #if os(macOS)
            settingsSidebar
                .navigationTitle(L10n.settingsTitle)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(theme.textSecondary)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(theme.cardBackground))
                        }
                        .buttonStyle(.plain)
                    }
                }
            #else
            settingsSidebar
                .navigationTitle(L10n.settingsTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(theme.textSecondary)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(theme.cardBackground))
                        }
                        .buttonStyle(.plain)
                    }
                }
            #endif
        }
        .sheet(isPresented: $showSleepCalculator) {
            SleepCalculatorSheet(theme: theme)
        }
        .frame(width: 720, height: 620)
    }
    
    private var settingsSidebar: some View {
        HStack(spacing: 0) {
            // Left sidebar
            VStack(alignment: .leading, spacing: 0) {
                Text(L10n.settingsTitle)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                
                VStack(spacing: 2) {
                    ForEach(SettingsTab.topTabs, id: \.self) { tab in
                        settingsSidebarRow(tab: tab)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 2) {
                    ForEach(SettingsTab.bottomTabs, id: \.self) { tab in
                        settingsSidebarRow(tab: tab)
                    }
                }
                .padding(.bottom, 16)
            }
            .frame(minWidth: 220, maxWidth: 220, maxHeight: .infinity)
            .background(theme.sidebarBackground)
            
            // Divider
            Rectangle()
                .fill(theme.divider)
                .frame(width: 1)
            
            // Right content
            VStack(alignment: .leading, spacing: 0) {
                Text(selectedSettingsTab.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                
                ScrollView {
                    settingsTabContent
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .background(theme.background)
        }
    }
    
    private func settingsSidebarRow(tab: SettingsTab) -> some View {
        Button(action: { selectedSettingsTab = tab }) {
            HStack(spacing: 12) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16))
                    .foregroundColor(selectedSettingsTab == tab ? .white : tab.iconColor)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedSettingsTab == tab ? tab.iconColor : tab.iconColor.opacity(0.15))
                    )
                
                Text(tab.title)
                    .font(.system(size: 15, weight: selectedSettingsTab == tab ? .semibold : .regular))
                    .foregroundColor(selectedSettingsTab == tab ? theme.textPrimary : theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selectedSettingsTab == tab ? JarvisTheme.accent.opacity(0.15) : Color.clear)
            )
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var settingsTabContent: some View {
        switch selectedSettingsTab {
        case .account:
            SettingsAccountTab(theme: theme)
        case .subscription:
            SettingsSubscriptionTab(theme: theme)
        case .calendars:
            SettingsCalendarsTab(theme: theme)
        case .customization:
            SettingsCustomizationTab(theme: theme, showSleepCalculator: $showSleepCalculator)
        case .advanced:
            SettingsAdvancedTab(theme: theme)
        case .helpFeedback:
            SettingsHelpTab(theme: theme)
        case .privacy:
            SettingsPrivacyTab(theme: theme)
        case .logOut:
            SettingsLogOutTab(theme: theme)
        }
    }
}

// MARK: - Settings Tab Enum

enum SettingsTab: String, CaseIterable {
    case account = "Account"
    case subscription = "Subscription"
    case calendars = "Calendars"
    case customization = "Customization"
    case advanced = "Advanced"
    case helpFeedback = "Help & Feedback"
    case privacy = "Privacy"
    case logOut = "Log Out"
    
    var title: String {
        switch self {
        case .account: return L10n.settingsTabAccount
        case .subscription: return L10n.settingsTabSubscription
        case .calendars: return L10n.settingsTabCalendars
        case .customization: return L10n.settingsTabCustomization
        case .advanced: return L10n.settingsTabAdvanced
        case .helpFeedback: return L10n.settingsTabHelpFeedback
        case .privacy: return L10n.settingsTabPrivacy
        case .logOut: return L10n.settingsTabLogOut
        }
    }
    
    var icon: String {
        switch self {
        case .account: return "person.crop.circle.fill"
        case .subscription: return "star.fill"
        case .calendars: return "calendar"
        case .customization: return "paintbrush.fill"
        case .advanced: return "gearshape.2.fill"
        case .helpFeedback: return "questionmark.circle.fill"
        case .privacy: return "lock.shield.fill"
        case .logOut: return "rectangle.portrait.and.arrow.right"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .account: return JarvisTheme.accent
        case .subscription: return JarvisTheme.accentYellow
        case .calendars: return JarvisTheme.accentBlue
        case .customization: return JarvisTheme.accentPurple
        case .advanced: return JarvisTheme.accentTeal
        case .helpFeedback: return JarvisTheme.accentGreen
        case .privacy: return JarvisTheme.accentBlue
        case .logOut: return JarvisTheme.accentOrange
        }
    }
    
    static var topTabs: [SettingsTab] { [.account, .subscription, .calendars, .customization, .advanced, .helpFeedback] }
    static var bottomTabs: [SettingsTab] { [.privacy, .logOut] }
}

// MARK: - Account Tab

struct SettingsAccountTab: View {
    let theme: JarvisTheme
    @StateObject private var cloudSync = CloudSync.shared
    @StateObject private var store = PlannerStore.shared
    @State private var showDeleteAllConfirm = false
    @State private var showResetConfirm = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Structured Cloud section
            settingsCard(title: L10n.settingsStructuredCloud) {
                VStack(spacing: 12) {
                    // Sync status
                    HStack {
                        Text(L10n.settingsSyncLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(theme.textTertiary)
                        Spacer()
                        Button(action: { cloudSync.forceSync() }) {
                            Text(L10n.settingsResync)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(JarvisTheme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: cloudSync.isSyncing ? "icloud" : "checkmark.icloud.fill")
                            .font(.system(size: 18))
                            .foregroundColor(theme.textSecondary)
                        
                        Text(cloudSync.isSyncing ? L10n.settingsSyncInProgress : (cloudSync.lastSyncDate != nil ? L10n.settingsSynced : L10n.settingsICloudEnabled))
                            .font(.system(size: 15))
                            .foregroundColor(theme.textPrimary)
                        
                        if cloudSync.isSyncing {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        
                        Spacer()
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(theme.cardBackground.opacity(0.5))
                    )
                    
                    if let err = cloudSync.syncError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(JarvisTheme.accentOrange)
                            Text(err)
                                .font(.system(size: 12))
                                .foregroundColor(JarvisTheme.accentOrange)
                        }
                    }
                    
                    // Account
                    HStack {
                        Text(L10n.settingsAccountLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(theme.textTertiary)
                        Spacer()
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: "at")
                            .font(.system(size: 16))
                            .foregroundColor(theme.textSecondary)
                        Text(L10n.settingsICloudAccount)
                            .font(.system(size: 15))
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(theme.cardBackground.opacity(0.5))
                    )
                }
            }
            
            // Danger Zone
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.settingsDangerZone)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                HStack(spacing: 12) {
                    Button(action: { showDeleteAllConfirm = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 14))
                            Text(L10n.settingsDeleteAccount)
                                .font(.system(size: 14, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .fixedSize()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.red.opacity(0.5), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { showResetConfirm = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 14))
                            Text(L10n.settingsResetApp)
                                .font(.system(size: 14, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundColor(JarvisTheme.accentOrange)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .fixedSize()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(JarvisTheme.accentOrange.opacity(0.5), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
            }
        }
        .confirmationDialog(L10n.settingsDeleteAllData, isPresented: $showDeleteAllConfirm, titleVisibility: .visible) {
            Button(L10n.settingsDeleteEverything, role: .destructive) {
                NotificationManager.shared.cancelAll()
                store.removeAll()
            }
            Button(L10n.cancel, role: .cancel) { }
        } message: {
            Text(L10n.settingsDeleteAllDataDesc)
        }
        .confirmationDialog(L10n.settingsResetAppConfirm, isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button(L10n.settingsResetAction, role: .destructive) {
                UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
                NotificationManager.shared.cancelAll()
                store.removeAll()
            }
            Button(L10n.cancel, role: .cancel) { }
        } message: {
            Text(L10n.settingsResetDesc)
        }
    }
    
    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(theme.textPrimary)
            
            VStack(spacing: 0) {
                content()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.cardBackground)
            )
        }
    }
}

// MARK: - Subscription Tab

struct SettingsSubscriptionTab: View {
    let theme: JarvisTheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Current plan
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.settingsCurrentPlan)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(JarvisTheme.accentYellow.opacity(0.15))
                            .frame(width: 56, height: 56)
                        Image(systemName: "star.fill")
                            .font(.system(size: 26))
                            .foregroundColor(JarvisTheme.accentYellow)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.settingsFreePlan)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(theme.textPrimary)
                        Text(L10n.settingsBasicFeatures)
                            .font(.system(size: 14))
                            .foregroundColor(theme.textSecondary)
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackground)
                )
            }
            
            // Features
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.settingsProFeatures)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                VStack(spacing: 0) {
                    featureRow(icon: "icloud.fill", title: L10n.settingsCloudSync, subtitle: L10n.settingsCloudSyncDesc, included: true)
                    Divider().foregroundColor(theme.divider).padding(.leading, 52)
                    featureRow(icon: "brain.head.profile", title: L10n.settingsAIAssistant, subtitle: L10n.settingsAIAssistantDesc, included: true)
                    Divider().foregroundColor(theme.divider).padding(.leading, 52)
                    featureRow(icon: "chart.bar.fill", title: L10n.settingsAdvancedAnalytics, subtitle: L10n.settingsAdvancedAnalyticsDesc, included: true)
                    Divider().foregroundColor(theme.divider).padding(.leading, 52)
                    featureRow(icon: "calendar.badge.clock", title: L10n.settingsCalendarIntegration, subtitle: L10n.settingsCalendarIntegrationDesc, included: true)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackground)
                )
            }
        }
    }
    
    private func featureRow(icon: String, title: String, subtitle: String, included: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(JarvisTheme.accentBlue)
                .frame(width: 36)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(theme.textSecondary)
            }
            
            Spacer()
            
            if included {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(JarvisTheme.accentGreen)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Calendars Tab

struct SettingsCalendarsTab: View {
    let theme: JarvisTheme
    @StateObject private var calendarSync = CalendarSyncService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.settingsCalendarAccess)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                VStack(spacing: 0) {
                    Button(action: {
                        Task { _ = await calendarSync.requestAccess() }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 20))
                                .foregroundColor(JarvisTheme.accentBlue)
                                .frame(width: 36)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.settingsSystemCalendar)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(theme.textPrimary)
                                Text(calendarSync.isAuthorizedForCalendar ? L10n.settingsConnected : L10n.settingsTapToConnect)
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.textSecondary)
                            }
                            
                            Spacer()
                            
                            if calendarSync.isAuthorizedForCalendar {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(JarvisTheme.accentGreen)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(theme.textTertiary)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    
                    Divider().foregroundColor(theme.divider).padding(.leading, 48)
                    
                    Toggle(isOn: Binding(
                        get: { calendarSync.syncToCalendarEnabled },
                        set: { calendarSync.setSyncToCalendarEnabled($0) }
                    )) {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 20))
                                .foregroundColor(JarvisTheme.accentTeal)
                                .frame(width: 36)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.settingsTwoWaySync)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(theme.textPrimary)
                                Text(L10n.settingsTwoWaySyncDesc)
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackground)
                )
            }
        }
    }
}

// MARK: - Customization Tab

struct SettingsCustomizationTab: View {
    let theme: JarvisTheme
    @Binding var showSleepCalculator: Bool
    @StateObject private var themeManager = ThemeManager.shared
    @ObservedObject private var aiManager = DependencyContainer.shared.aiManager
    @ObservedObject private var langManager = LanguageManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Theme
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.settingsAppearanceLabel)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                VStack(spacing: 0) {
                    ForEach(ThemeMode.allCases, id: \.self) { mode in
                        themeRow(mode: mode)
                        if mode != ThemeMode.allCases.last {
                            Divider().foregroundColor(theme.divider).padding(.leading, 56)
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackground)
                )
            }
            
            // Dock magnification
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.settingsInteractions)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                VStack(spacing: 0) {
                    Toggle(isOn: Binding(
                        get: { UserDefaults.standard.object(forKey: Config.Storage.dockMagnificationKey) as? Bool ?? true },
                        set: { UserDefaults.standard.set($0, forKey: Config.Storage.dockMagnificationKey) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.settingsDockMagnification)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(theme.textPrimary)
                            Text(L10n.settingsDockMagnificationDesc)
                                .font(.system(size: 12))
                                .foregroundColor(theme.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackground)
                )
            }
            
            // AI Model
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.settingsAIModelLabel)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                VStack(spacing: 0) {
                    Picker(L10n.settingsAIModelLabel, selection: Binding(
                        get: { aiManager.selectedModel },
                        set: { aiManager.selectedModel = $0 }
                    )) {
                        ForEach(AIModel.allCases) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                    .foregroundColor(theme.textPrimary)
                    
                    Text(L10n.settingsAIModelDesc2)
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)
                        .padding(.top, 4)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackground)
                )
            }
            
            // Sleep calculator
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.settingsWellness)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                Button(action: { showSleepCalculator = true }) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(JarvisTheme.accentPurple.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "moon.zzz.fill")
                                .font(.system(size: 20))
                                .foregroundColor(JarvisTheme.accentPurple)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.settingsSleepCalculator)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(theme.textPrimary)
                            Text(L10n.settingsSleepCalcDesc)
                                .font(.system(size: 12))
                                .foregroundColor(theme.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(theme.textTertiary)
                    }
                }
                .buttonStyle(.plain)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackground)
                )
            }
            
            // Language
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.settingsLanguage)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                VStack(spacing: 0) {
                    ForEach(AppLanguage.allCases) { lang in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                langManager.language = lang
                            }
                        }) {
                            HStack(spacing: 16) {
                                Text(lang.flag)
                                    .font(.system(size: 24))
                                    .frame(width: 40, height: 40)
                                
                                Text(lang.displayName)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(theme.textPrimary)
                                
                                Spacer()
                                
                                if langManager.language == lang {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(JarvisTheme.accent)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        
                        if lang != AppLanguage.allCases.last {
                            Divider().foregroundColor(theme.divider).padding(.leading, 56)
                        }
                    }
                    
                    Text(L10n.settingsLanguageDesc)
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)
                        .padding(.top, 8)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackground)
                )
            }
        }
    }
    
    private func themeRow(mode: ThemeMode) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                themeManager.currentTheme = mode
            }
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(themeBackgroundColor(for: mode))
                        .frame(width: 40, height: 40)
                    Image(systemName: themeIcon(for: mode))
                        .font(.system(size: 18))
                        .foregroundColor(themeIconColor(for: mode))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.displayName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(theme.textPrimary)
                }
                
                Spacer()
                
                if themeManager.currentTheme == mode {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(JarvisTheme.accent)
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
    
    private func themeIcon(for mode: ThemeMode) -> String {
        switch mode {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }
    
    private func themeBackgroundColor(for mode: ThemeMode) -> Color {
        switch mode {
        case .light: return Color(red: 1.0, green: 0.95, blue: 0.8)
        case .dark: return Color(red: 0.15, green: 0.15, blue: 0.2)
        case .system: return Color(red: 0.5, green: 0.5, blue: 0.55)
        }
    }
    
    private func themeIconColor(for mode: ThemeMode) -> Color {
        switch mode {
        case .light: return Color.orange
        case .dark: return Color.purple
        case .system: return Color.white
        }
    }
}

// MARK: - Advanced Tab

struct SettingsAdvancedTab: View {
    let theme: JarvisTheme
    @StateObject private var store = PlannerStore.shared
    @State private var shareURL: IdentifiableURL?
    @State private var showImportPicker = false
    @State private var importMessage: String?
    @State private var showImportResult = false
    @State private var showDeleteCompletedConfirm = false
    @State private var showMessengerSettings = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Notifications
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.settingsNotificationsLabel)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                VStack(spacing: 0) {
                    Toggle(isOn: Binding(
                        get: { UserDefaults.standard.object(forKey: "jarvis_notifications_enabled") as? Bool ?? true },
                        set: { UserDefaults.standard.set($0, forKey: "jarvis_notifications_enabled") }
                    )) {
                        HStack(spacing: 12) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 18))
                                .foregroundColor(JarvisTheme.accentOrange)
                                .frame(width: 36)
                            Text(L10n.settingsRemindersLabel)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(theme.textPrimary)
                        }
                    }
                    .padding(.vertical, 6)
                    
                    Divider().foregroundColor(theme.divider).padding(.leading, 48)
                    
                    Toggle(isOn: Binding(
                        get: { UserDefaults.standard.object(forKey: "jarvis_notification_sound") as? Bool ?? true },
                        set: { UserDefaults.standard.set($0, forKey: "jarvis_notification_sound") }
                    )) {
                        HStack(spacing: 12) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 18))
                                .foregroundColor(JarvisTheme.accentPurple)
                                .frame(width: 36)
                            Text(L10n.settingsSoundLabel)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(theme.textPrimary)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackground)
                )
            }
            
            // AI Skills
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.settingsAISkillsLabel)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                VStack(spacing: 0) {
                    aiSkillToggle(title: L10n.settingsCalendarSkill, icon: "calendar", key: Config.Storage.skillCalendarKey, color: JarvisTheme.accentBlue)
                    Divider().foregroundColor(theme.divider).padding(.leading, 48)
                    aiSkillToggle(title: L10n.settingsMailSkill, icon: "envelope.fill", key: Config.Storage.skillMailKey, color: JarvisTheme.accentOrange)
                    Divider().foregroundColor(theme.divider).padding(.leading, 48)
                    aiSkillToggle(title: L10n.settingsDeepAnalysis, icon: "brain", key: Config.Storage.skillDeepAnalysisKey, color: JarvisTheme.accentPurple)
                    Divider().foregroundColor(theme.divider).padding(.leading, 48)
                    aiSkillToggle(title: L10n.settingsVoiceInputLabel, icon: "mic.fill", key: Config.Storage.skillVoiceKey, color: JarvisTheme.accentTeal)
                    Divider().foregroundColor(theme.divider).padding(.leading, 48)
                    aiSkillToggle(title: L10n.settingsTelegram, icon: "paperplane.fill", key: Config.Storage.skillTelegramKey, color: Color(red: 0.07, green: 0.72, blue: 0.34))
                    Divider().foregroundColor(theme.divider).padding(.leading, 48)
                    aiSkillToggle(title: L10n.settingsWhatsApp, icon: "bubble.left.and.bubble.right.fill", key: Config.Storage.skillWhatsAppKey, color: Color(red: 0.14, green: 0.80, blue: 0.44))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackground)
                )
                
                // Messenger configuration button
                Button(action: { showMessengerSettings = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18))
                            .foregroundColor(JarvisTheme.accentTeal)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.settingsConfigureMessengers)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(theme.textPrimary)
                            Text(L10n.settingsConfigureMessengersDesc)
                                .font(.caption2)
                                .foregroundColor(theme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(theme.cardBackground)
                    )
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showMessengerSettings) {
                    MessengerSettingsView()
                }
            }
            
            // Data
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.settingsDataManagement)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                VStack(spacing: 0) {
                    Button(action: {
                        if let url = ExportImport.createExportURL(store: store) {
                            shareURL = IdentifiableURL(url: url)
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 18))
                                .foregroundColor(JarvisTheme.accentBlue)
                                .frame(width: 36)
                            Text(L10n.settingsExportData)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(theme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(theme.textTertiary)
                        }
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    
                    Divider().foregroundColor(theme.divider).padding(.leading, 48)
                    
                    Button(action: { showImportPicker = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 18))
                                .foregroundColor(JarvisTheme.accentGreen)
                                .frame(width: 36)
                            Text(L10n.settingsImportData)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(theme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(theme.textTertiary)
                        }
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    
                    Divider().foregroundColor(theme.divider).padding(.leading, 48)
                    
                    Button(action: { showDeleteCompletedConfirm = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "trash")
                                .font(.system(size: 18))
                                .foregroundColor(JarvisTheme.accentOrange)
                                .frame(width: 36)
                            Text(L10n.settingsClearCompletedLabel)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(JarvisTheme.accentOrange)
                            Spacer()
                        }
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.tasks.filter(\.isCompleted).isEmpty)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackground)
                )
            }
            
            // Stats
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.settingsStatistics)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                HStack(spacing: 12) {
                    statBadge(title: L10n.settingsTotal, value: "\(store.tasks.count)", color: JarvisTheme.accent)
                    statBadge(title: L10n.settingsDone, value: "\(store.tasks.filter(\.isCompleted).count)", color: JarvisTheme.accentGreen)
                    statBadge(title: L10n.settingsInbox, value: "\(store.tasks.filter { $0.isInbox && !$0.isCompleted }.count)", color: JarvisTheme.accentOrange)
                }
            }
            
            // About
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.settingsAboutLabel)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                VStack(spacing: 0) {
                    HStack {
                        Text(L10n.settingsVersionLabel)
                            .font(.system(size: 15))
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                        Text(Bundle.main.appVersion)
                            .font(.system(size: 14))
                            .foregroundColor(theme.textSecondary)
                    }
                    .padding(.vertical, 8)
                    
                    Divider().foregroundColor(theme.divider)
                    
                    HStack {
                        Text(L10n.settingsBuildLabel)
                            .font(.system(size: 15))
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                        Text(Bundle.main.buildNumber)
                            .font(.system(size: 14))
                            .foregroundColor(theme.textSecondary)
                    }
                    .padding(.vertical, 8)
                    
                    Divider().foregroundColor(theme.divider)
                    
                    Button(action: { OnboardingManager.shared.resetOnboarding() }) {
                        HStack {
                            Text(L10n.settingsReplayOnboarding)
                                .font(.system(size: 15))
                                .foregroundColor(JarvisTheme.accentBlue)
                            Spacer()
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 14))
                                .foregroundColor(JarvisTheme.accentBlue)
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackground)
                )
            }
        }
        .sheet(item: $shareURL) { item in
            #if os(iOS)
            ShareSheetView(items: [item.url])
            #else
            EmptyView()
            #endif
        }
        .alert(L10n.settingsImportLabel, isPresented: $showImportResult) {
            Button("OK", role: .cancel) { }
        } message: {
            if let msg = importMessage { Text(msg) }
        }
        .confirmationDialog(L10n.settingsClearCompletedConfirm, isPresented: $showDeleteCompletedConfirm, titleVisibility: .visible) {
            Button(L10n.deleteAction, role: .destructive) {
                NotificationManager.shared.cancelAll()
                store.removeCompleted()
            }
            Button(L10n.cancel, role: .cancel) { }
        }
        #if os(iOS)
        .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            Task { @MainActor in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    guard url.startAccessingSecurityScopedResource() else {
                        importMessage = L10n.settingsNoAccess
                        showImportResult = true
                        return
                    }
                    defer { url.stopAccessingSecurityScopedResource() }
                    importMessage = ExportImport.importFromURL(url, store: store, merge: true)
                    showImportResult = true
                case .failure:
                    importMessage = L10n.settingsFileSelectionError
                    showImportResult = true
                }
            }
        }
        #endif
    }
    
    private func aiSkillToggle(title: String, icon: String, key: String, color: Color) -> some View {
        Toggle(isOn: Binding(
            get: { UserDefaults.standard.object(forKey: key) as? Bool ?? true },
            set: { UserDefaults.standard.set($0, forKey: key) }
        )) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                    .frame(width: 36)
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(theme.textPrimary)
            }
        }
        .padding(.vertical, 6)
    }
    
    private func statBadge(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.cardBackground)
        )
    }
}

// MARK: - Help & Feedback Tab

struct SettingsHelpTab: View {
    let theme: JarvisTheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.settingsHelpFeedbackTitle)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                VStack(spacing: 0) {
                    helpRow(icon: "book.fill", title: L10n.settingsUserGuide, subtitle: L10n.settingsUserGuideDesc, color: JarvisTheme.accentBlue)
                    Divider().foregroundColor(theme.divider).padding(.leading, 48)
                    helpRow(icon: "envelope.fill", title: L10n.settingsContactSupport, subtitle: L10n.settingsContactSupportDesc, color: JarvisTheme.accentGreen)
                    Divider().foregroundColor(theme.divider).padding(.leading, 48)
                    helpRow(icon: "star.fill", title: L10n.settingsRateAppStore, subtitle: L10n.settingsRateAppStoreDesc, color: JarvisTheme.accentYellow)
                    Divider().foregroundColor(theme.divider).padding(.leading, 48)
                    helpRow(icon: "ant.fill", title: L10n.settingsReportBug, subtitle: L10n.settingsReportBugDesc, color: JarvisTheme.accentOrange)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackground)
                )
            }
        }
    }
    
    private func helpRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
        Button(action: { }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                    .frame(width: 36)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(theme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(theme.textTertiary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Privacy Tab

struct SettingsPrivacyTab: View {
    let theme: JarvisTheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Hero section
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [JarvisTheme.accentBlue.opacity(0.3), JarvisTheme.accentPurple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 36))
                        .foregroundColor(JarvisTheme.accentBlue)
                }
                
                Text(L10n.settingsPrivacyTitle)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                Text(L10n.settingsPrivacyDesc)
                    .font(.system(size: 14))
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            
            // Data handling 
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.settingsDataHandling)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                VStack(spacing: 0) {
                    privacyRow(icon: "iphone", title: L10n.settingsLocalStorage, description: L10n.settingsLocalStorageDesc, status: L10n.settingsActive)
                    Divider().foregroundColor(theme.divider).padding(.leading, 48)
                    privacyRow(icon: "icloud.fill", title: L10n.settingsICloudSync, description: L10n.settingsICloudSyncDesc, status: L10n.settingsActive)
                    Divider().foregroundColor(theme.divider).padding(.leading, 48)
                    privacyRow(icon: "brain.head.profile", title: L10n.settingsAIProcessing, description: L10n.settingsAIProcessingDesc, status: L10n.settingsOptional)
                    Divider().foregroundColor(theme.divider).padding(.leading, 48)
                    privacyRow(icon: "location.slash.fill", title: L10n.settingsLocationData, description: L10n.settingsLocationDataDesc, status: L10n.settingsNever)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackground)
                )
            }
            
            // Legal links
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.settingsLegal)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                VStack(spacing: 0) {
                    legalRow(title: L10n.settingsTerms, icon: "doc.text.fill")
                    Divider().foregroundColor(theme.divider).padding(.leading, 48)
                    legalRow(title: L10n.settingsPrivacyPolicy, icon: "hand.raised.fill")
                    Divider().foregroundColor(theme.divider).padding(.leading, 48)
                    legalRow(title: L10n.settingsDataProcessing, icon: "doc.on.doc.fill")
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackground)
                )
            }
            
            // Data rights
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.settingsYourRights)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                VStack(spacing: 0) {
                    rightRow(icon: "arrow.down.doc.fill", title: L10n.settingsExportYourData, description: L10n.settingsExportYourDataDesc, color: JarvisTheme.accentBlue)
                    Divider().foregroundColor(theme.divider).padding(.leading, 48)
                    rightRow(icon: "trash.fill", title: L10n.settingsDeleteAllDataLabel, description: L10n.settingsDeleteAllDataLabelDesc, color: .red)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackground)
                )
            }
        }
    }
    
    private func privacyRow(icon: String, title: String, description: String, status: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(JarvisTheme.accentBlue)
                .frame(width: 36)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(theme.textPrimary)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(theme.textSecondary)
            }
            
            Spacer()
            
            Text(status)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(status == "Never" ? JarvisTheme.accentGreen : JarvisTheme.accentBlue)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill((status == "Never" ? JarvisTheme.accentGreen : JarvisTheme.accentBlue).opacity(0.15))
                )
        }
        .padding(.vertical, 8)
    }
    
    private func legalRow(title: String, icon: String) -> some View {
        Button(action: { }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(JarvisTheme.accentPurple)
                    .frame(width: 36)
                
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(theme.textPrimary)
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12))
                    .foregroundColor(theme.textTertiary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
    
    private func rightRow(icon: String, title: String, description: String, color: Color) -> some View {
        Button(action: { }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                    .frame(width: 36)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(color)
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(theme.textTertiary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Log Out Tab

struct SettingsLogOutTab: View {
    let theme: JarvisTheme
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(JarvisTheme.accentOrange.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 36))
                    .foregroundColor(JarvisTheme.accentOrange)
            }
            
            Text(L10n.settingsLogOutTitle)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(theme.textPrimary)
            
            Text(L10n.settingsLogOutDesc)
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: { }) {
                Text(L10n.settingsLogOutAction)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: 260)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(JarvisTheme.accentOrange)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
