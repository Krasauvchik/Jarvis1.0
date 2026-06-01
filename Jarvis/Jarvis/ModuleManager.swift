import SwiftUI

// MARK: - Module Manager
// Things 3 / Structured-inspired progressive disclosure system.
// By default only core task-management sections are visible.
// Users toggle extra modules on/off via Settings → Sidebar Modules or during onboarding.

@MainActor @Observable
final class ModuleManager {
    static let shared = ModuleManager()

    // MARK: - Module Definition

    /// Every NavigationSection that can be toggled by the user.
    /// Core sections (inbox, today, scheduled, completed, all) are always visible and not listed here.
    struct Module: Identifiable {
        let section: NavigationSection
        let descriptionKey: String   // L10n key for short description
        let group: ModuleGroup

        var id: String { section.rawValue }
    }

    enum ModuleGroup: String, CaseIterable {
        case productivity
        case integrations
        case wellness

        var localizedName: String {
            switch self {
            case .productivity: return L10n.moduleGroupProductivity
            case .integrations: return L10n.moduleGroupIntegrations
            case .wellness: return L10n.moduleGroupWellness
            }
        }

        var icon: String {
            switch self {
            case .productivity: return "square.grid.2x2"
            case .integrations: return "link"
            case .wellness: return "heart.fill"
            }
        }
    }

    /// All toggleable modules
    static let allModules: [Module] = [
        // Productivity
        Module(section: .kanban,          descriptionKey: "module_desc_kanban",       group: .productivity),
        Module(section: .projects,        descriptionKey: "module_desc_projects",     group: .productivity),
        Module(section: .templates,       descriptionKey: "module_desc_templates",    group: .productivity),
        Module(section: .habits,          descriptionKey: "module_desc_habits",       group: .productivity),
        Module(section: .focus,           descriptionKey: "module_desc_focus",        group: .productivity),
        Module(section: .analytics,       descriptionKey: "module_desc_analytics",    group: .productivity),
        Module(section: .registries,      descriptionKey: "module_desc_registries",   group: .productivity),
        // Integrations
        Module(section: .systemCalendar,  descriptionKey: "module_desc_sys_calendar", group: .integrations),
        Module(section: .mailSection,     descriptionKey: "module_desc_mail",         group: .integrations),
        Module(section: .messengers,      descriptionKey: "module_desc_messengers",   group: .integrations),
        Module(section: .chat,            descriptionKey: "module_desc_chat",         group: .integrations),
        // Wellness
        Module(section: .health,          descriptionKey: "module_desc_health",       group: .wellness),
        Module(section: .futurePlans,     descriptionKey: "module_desc_future",       group: .wellness),
    ]

    // MARK: - Core Sections (always visible, like Things 3)

    static let coreSections: [NavigationSection] = [
        .inbox, .today, .scheduled, .completed, .all
    ]

    // MARK: - State

    /// Set of enabled module section rawValues, persisted via UserDefaults.
    var enabledModuleIDs: Set<String> {
        didSet { persist() }
    }

    /// Section ordering (rawValues). Users can reorder modules.
    var sectionOrder: [String] {
        didSet { persistOrder() }
    }

    private let storageKey = "jarvis_enabled_modules"
    private let orderKey = "jarvis_module_order"
    private let initializedKey = "jarvis_modules_initialized"

    // MARK: - Default Modules (Things 3-like minimal set)

    /// These modules are ON by default for new installs — a clean, focused set.
    static let defaultEnabledIDs: Set<String> = [] // Start truly minimal — only core sections

    private init() {
        let initialized = UserDefaults.standard.bool(forKey: initializedKey)
        if initialized, let saved = UserDefaults.standard.stringArray(forKey: storageKey) {
            self.enabledModuleIDs = Set(saved)
        } else {
            self.enabledModuleIDs = Self.defaultEnabledIDs
        }

        if let savedOrder = UserDefaults.standard.stringArray(forKey: orderKey) {
            self.sectionOrder = savedOrder
        } else {
            self.sectionOrder = Self.allModules.map { $0.section.rawValue }
        }

        if !initialized {
            UserDefaults.standard.set(true, forKey: initializedKey)
            persist()
            persistOrder()
        }
    }

    // MARK: - Public API

    func isEnabled(_ section: NavigationSection) -> Bool {
        Self.coreSections.contains(section) || enabledModuleIDs.contains(section.rawValue)
    }

    func toggle(_ section: NavigationSection) {
        if enabledModuleIDs.contains(section.rawValue) {
            enabledModuleIDs.remove(section.rawValue)
        } else {
            enabledModuleIDs.insert(section.rawValue)
        }
    }

    func setEnabled(_ section: NavigationSection, enabled: Bool) {
        if enabled {
            enabledModuleIDs.insert(section.rawValue)
        } else {
            enabledModuleIDs.remove(section.rawValue)
        }
    }

    func enablePreset(_ preset: ModulePreset) {
        for id in preset.moduleIDs {
            enabledModuleIDs.insert(id)
        }
    }

    /// Sections visible for the given app mode, filtered by what the user has enabled.
    func visibleSections(for mode: AppMode) -> [NavigationSection] {
        let modeAll = mode.allAvailableSections
        // Core sections first (in fixed order), then toggled modules in user order
        let core = Self.coreSections.filter { modeAll.contains($0) }
        let extras = orderedModules
            .map { $0.section }
            .filter { enabledModuleIDs.contains($0.rawValue) && modeAll.contains($0) }
        return core + extras
    }

    /// All modules sorted by the user's custom order.
    var orderedModules: [Module] {
        let lookup = Dictionary(uniqueKeysWithValues: Self.allModules.map { ($0.section.rawValue, $0) })
        var result: [Module] = []
        for id in sectionOrder {
            if let mod = lookup[id] { result.append(mod) }
        }
        // Append any new modules not yet in order
        for mod in Self.allModules where !sectionOrder.contains(mod.section.rawValue) {
            result.append(mod)
        }
        return result
    }

    func moveModule(from source: IndexSet, to destination: Int) {
        var order = orderedModules.map { $0.section.rawValue }
        order.move(fromOffsets: source, toOffset: destination)
        sectionOrder = order
    }

    // MARK: - Persistence

    private func persist() {
        UserDefaults.standard.set(Array(enabledModuleIDs), forKey: storageKey)
    }

    private func persistOrder() {
        UserDefaults.standard.set(sectionOrder, forKey: orderKey)
    }
}

// MARK: - Module Presets (quick-setup templates)

enum ModulePreset: String, CaseIterable, Identifiable {
    case minimal       // Things 3 style — tasks only
    case structured    // Structured-like — tasks + calendar + focus
    case powerUser     // Everything on
    case teamWork      // Tasks + Kanban + Projects + Mail + Messenger

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .minimal:    return L10n.presetMinimal
        case .structured: return L10n.presetStructured
        case .powerUser:  return L10n.presetPowerUser
        case .teamWork:   return L10n.presetTeamWork
        }
    }

    var description: String {
        switch self {
        case .minimal:    return L10n.presetMinimalDesc
        case .structured: return L10n.presetStructuredDesc
        case .powerUser:  return L10n.presetPowerUserDesc
        case .teamWork:   return L10n.presetTeamWorkDesc
        }
    }

    var icon: String {
        switch self {
        case .minimal:    return "leaf.fill"
        case .structured: return "rectangle.split.3x1.fill"
        case .powerUser:  return "bolt.fill"
        case .teamWork:   return "person.3.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .minimal:    return JarvisTheme.accentGreen
        case .structured: return JarvisTheme.accent
        case .powerUser:  return JarvisTheme.accentPurple
        case .teamWork:   return JarvisTheme.accentBlue
        }
    }

    var moduleIDs: Set<String> {
        switch self {
        case .minimal:
            return []
        case .structured:
            return [
                NavigationSection.calendarSection.rawValue,
                NavigationSection.focus.rawValue,
                NavigationSection.habits.rawValue,
            ]
        case .powerUser:
            return Set(ModuleManager.allModules.map { $0.section.rawValue })
        case .teamWork:
            return [
                NavigationSection.kanban.rawValue,
                NavigationSection.projects.rawValue,
                NavigationSection.mailSection.rawValue,
                NavigationSection.messengers.rawValue,
                NavigationSection.analytics.rawValue,
                NavigationSection.chat.rawValue,
            ]
        }
    }
}

// MARK: - AppMode Extension

extension AppMode {
    /// All sections this mode *could* show (before module filtering).
    var allAvailableSections: [NavigationSection] {
        switch self {
        case .work:
            return [.inbox, .today, .scheduled, .completed, .all, .kanban, .templates,
                    .habits, .focus, .calendarSection, .systemCalendar, .mailSection,
                    .messengers, .analytics, .registries, .projects, .chat]
        case .personal:
            return [.inbox, .today, .scheduled, .completed, .all, .health, .habits,
                    .focus, .futurePlans, .calendarSection, .systemCalendar]
        }
    }
}
