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
                settingsSection(title: "Синхронизация", icon: "icloud.fill") {
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
                            Text("Включено")
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
                        Label("Синхронизировать сейчас", systemImage: "arrow.clockwise")
                            .foregroundColor(JarvisTheme.accent)
                    }
                    .buttonStyle(.plain)
                    .bounceOnTap()
                    .disabled(cloudSync.isSyncing)
                    .padding(.vertical, 4)
                }
                
                settingsSection(title: "Оформление", icon: "paintbrush.fill") {
                    ForEach(ThemeMode.allCases, id: \.self) { mode in
                        themeRow(mode: mode)
                    }
                    settingsToggle(
                        title: "Увеличение при наведении (как Dock)",
                        icon: "arrow.up.left.and.arrow.down.right",
                        isOn: Binding(
                            get: { UserDefaults.standard.object(forKey: Config.Storage.dockMagnificationKey) as? Bool ?? true },
                            set: { UserDefaults.standard.set($0, forKey: Config.Storage.dockMagnificationKey) }
                        )
                    )
                    Text("Увеличивать элементы меню и названия задач при наведении курсора или нажатии.")
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)
                        .padding(.top, 2)
                }
                
                settingsSection(title: "Нейросеть", icon: "brain.head.profile") {
                    Picker("Модель ИИ", selection: Binding(
                        get: { aiManager.selectedModel },
                        set: { aiManager.selectedModel = $0 }
                    )) {
                        ForEach(AIModel.allCases) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                    .foregroundColor(theme.textPrimary)
                    Text("Используется для разбора задач, советов и глубокого анализа.")
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)
                        .padding(.top, 4)
                }
                
                settingsSection(title: "Здоровье", icon: "heart.fill") {
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
                                Text("Калькулятор сна")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(theme.textPrimary)
                                Text("Рассчитать оптимальное время")
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
                
                settingsSection(title: "Календарь", icon: "calendar") {
                    Button(action: {
                        Task {
                            _ = await calendarSync.requestAccess()
                        }
                    }) {
                        HStack {
                            Label("Разрешить доступ к календарю", systemImage: "calendar.badge.plus")
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
                        Label("Синхронизировать задачи с Календарём", systemImage: "calendar")
                            .foregroundColor(theme.textPrimary)
                    }
                    .padding(.vertical, 4)
                }
                
                settingsSection(title: "Навыки ИИ", icon: "cpu") {
                    Text("Включите или отключите интеграции (в духе OpenClaw).")
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)
                        .padding(.bottom, 4)
                    settingsToggle(
                        title: "Календарь",
                        icon: "calendar",
                        isOn: Binding(
                            get: { UserDefaults.standard.object(forKey: Config.Storage.skillCalendarKey) as? Bool ?? true },
                            set: { UserDefaults.standard.set($0, forKey: Config.Storage.skillCalendarKey) }
                        )
                    )
                    settingsToggle(
                        title: "Почта",
                        icon: "envelope",
                        isOn: Binding(
                            get: { UserDefaults.standard.object(forKey: Config.Storage.skillMailKey) as? Bool ?? true },
                            set: { UserDefaults.standard.set($0, forKey: Config.Storage.skillMailKey) }
                        )
                    )
                    settingsToggle(
                        title: "Глубокий анализ",
                        icon: "brain",
                        isOn: Binding(
                            get: { UserDefaults.standard.object(forKey: Config.Storage.skillDeepAnalysisKey) as? Bool ?? true },
                            set: { UserDefaults.standard.set($0, forKey: Config.Storage.skillDeepAnalysisKey) }
                        )
                    )
                    settingsToggle(
                        title: "Голосовой ввод",
                        icon: "mic.fill",
                        isOn: Binding(
                            get: { UserDefaults.standard.object(forKey: Config.Storage.skillVoiceKey) as? Bool ?? true },
                            set: { UserDefaults.standard.set($0, forKey: Config.Storage.skillVoiceKey) }
                        )
                    )
                }
                
                settingsSection(title: "Уведомления", icon: "bell.badge.fill") {
                    settingsToggle(
                        title: "Напоминания",
                        icon: "bell.fill",
                        isOn: Binding(
                            get: { UserDefaults.standard.object(forKey: "jarvis_notifications_enabled") as? Bool ?? true },
                            set: { UserDefaults.standard.set($0, forKey: "jarvis_notifications_enabled") }
                        )
                    )
                    settingsToggle(
                        title: "Звук",
                        icon: "speaker.wave.2.fill",
                        isOn: Binding(
                            get: { UserDefaults.standard.object(forKey: "jarvis_notification_sound") as? Bool ?? true },
                            set: { UserDefaults.standard.set($0, forKey: "jarvis_notification_sound") }
                        )
                    )
                }
                
                settingsSection(title: "Статистика", icon: "chart.bar.fill") {
                    statsRow(title: "Всего задач", icon: "list.bullet", value: "\(store.tasks.count)", color: JarvisTheme.accent)
                    statsRow(title: "Выполнено", icon: "checkmark.circle", value: "\(store.tasks.filter { $0.isCompleted }.count)", color: JarvisTheme.accentGreen)
                    statsRow(title: "В Inbox", icon: "tray", value: "\(store.tasks.filter { $0.isInbox && !$0.isCompleted }.count)", color: JarvisTheme.accentOrange)
                }
                
                settingsSection(title: "Категории и теги", icon: "folder.fill") {
                    NavigationLink(destination: CategoriesTagsManageView(theme: theme)) {
                        HStack {
                            Label("Управление категориями и тегами", systemImage: "tag.fill")
                                .foregroundColor(theme.textPrimary)
                            Spacer()
                            Text("\(store.categories.count) / \(store.tags.count)")
                                .foregroundColor(theme.textSecondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                settingsSection(title: "Данные", icon: "externaldrive.fill") {
                    Button(action: {
                        if let url = ExportImport.createExportURL(store: store) {
                            shareURL = IdentifiableURL(url: url)
                        }
                    }) {
                        HStack {
                            Label("Экспорт данных", systemImage: "square.and.arrow.up")
                                .foregroundColor(theme.textPrimary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .bounceOnTap()
                    
                    Button(action: { showImportPicker = true }) {
                        HStack {
                            Label("Импорт данных", systemImage: "square.and.arrow.down")
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
                                    importMessage = "Нет доступа к файлу"
                                    showImportResult = true
                                    return
                                }
                                defer { url.stopAccessingSecurityScopedResource() }
                                importMessage = ExportImport.importFromURL(url, store: store, merge: importMerge)
                                showImportResult = true
                            case .failure:
                                importMessage = "Ошибка выбора файла"
                                showImportResult = true
                            }
                        }
                    }
                    #endif
                    
                    Button(action: { showDeleteCompletedConfirm = true }) {
                        HStack {
                            Label("Очистить выполненные", systemImage: "trash")
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
                            Label("Удалить все задачи", systemImage: "trash.fill")
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
                .alert("Импорт", isPresented: $showImportResult) {
                    Button("OK", role: .cancel) { }
                } message: {
                    if let msg = importMessage { Text(msg) }
                }
                
                settingsSection(title: "О приложении", icon: "info.circle.fill") {
                    HStack {
                        Label("Версия", systemImage: "info.circle")
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                        Text(Bundle.main.appVersion)
                            .foregroundColor(theme.textSecondary)
                    }
                    .padding(.vertical, 4)
                    
                    HStack {
                        Label("Сборка", systemImage: "hammer")
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
        .confirmationDialog("Удалить выполненные?", isPresented: $showDeleteCompletedConfirm, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) {
                NotificationManager.shared.cancelAll()
                store.removeCompleted()
            }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Будут удалены все задачи со статусом «выполнено».")
        }
        .confirmationDialog("Удалить все задачи?", isPresented: $showDeleteAllConfirm, titleVisibility: .visible) {
            Button("Удалить всё", role: .destructive) {
                NotificationManager.shared.cancelAll()
                store.removeAll()
            }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Все задачи и напоминания будут удалены. Это действие нельзя отменить.")
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
        case .light: return "Яркая и светлая тема"
        case .dark: return "Комфортно для глаз в темноте"
        case .system: return "Следует настройкам устройства"
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
        .navigationTitle("Категории и теги")
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
            Label("Категории", systemImage: "folder.fill")
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
                        .accessibilityLabel("Удалить категорию \(cat.name)")
                        .bounceOnTap()
                    }
                    .padding(.vertical, 8)
                }
                Button(action: { showAddCategory = true }) {
                    Label("Добавить категорию", systemImage: "plus.circle.fill")
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
            Label("Теги", systemImage: "tag.fill")
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
                        .accessibilityLabel("Удалить тег \(tag.name)")
                        .bounceOnTap()
                    }
                    .padding(.vertical, 8)
                }
                Button(action: { showAddTag = true }) {
                    Label("Добавить тег", systemImage: "plus.circle.fill")
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
                TextField("Название", text: $name)
                Section("Цвет") {
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
                Section("Иконка") {
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
            .navigationTitle(category == nil ? "Новая категория" : "Редактировать")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
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
                TextField("Название тега", text: $name)
                Section("Цвет") {
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
            .navigationTitle(tag == nil ? "Новый тег" : "Редактировать тег")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
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
    let theme: JarvisTheme
    
    var body: some View {
        NavigationStack {
            SettingsContent(theme: theme, showSleepCalculator: $showSleepCalculator)
                .navigationTitle("Настройки")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Готово") { dismiss() }
                    }
                }
                .sheet(isPresented: $showSleepCalculator) {
                    SleepCalculatorSheet(theme: theme)
                }
        }
    }
}
