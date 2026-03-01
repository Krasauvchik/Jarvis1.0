import Foundation
import Combine

/// Cloud synchronization manager with offline support (inspired by Task-Sync-Pro)
@MainActor
final class CloudSync: ObservableObject {
    static let shared = CloudSync()
    
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var syncError: String?
    @Published private(set) var pendingChanges = 0
    
    private var subscriptions = Set<AnyCancellable>()
    private let kvStore = NSUbiquitousKeyValueStore.default
    private var pendingTasks: [PlannerTask] = []
    /// Для синхронизации при восстановлении сети (логика как в Task-Sync-Pro).
    private var wasConnected = true
    
    private init() {
        setupNotifications()
        setupReconnectSync()
        kvStore.synchronize()
        loadLastSyncDate()
    }
    
    /// При появлении сети запускаем синхронизацию, чтобы подтянуть изменения с других устройств.
    private func setupReconnectSync() {
        wasConnected = NetworkMonitor.shared.isConnected
        NetworkMonitor.shared.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                guard let self else { return }
                if connected && !self.wasConnected {
                    self.forceSync()
                }
                self.wasConnected = connected
            }
            .store(in: &subscriptions)
    }
    
    private func loadLastSyncDate() {
        if let timestamp = UserDefaults.standard.object(forKey: "lastSyncTimestamp") as? TimeInterval {
            lastSyncDate = Date(timeIntervalSince1970: timestamp)
        }
    }
    
    private func saveLastSyncDate() {
        lastSyncDate = Date()
        UserDefaults.standard.set(lastSyncDate?.timeIntervalSince1970, forKey: "lastSyncTimestamp")
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &subscriptions)
    }
    
    // MARK: - Key-Value Store (Fast sync for small data)
    
    func saveTasks(_ tasks: [PlannerTask]) {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        kvStore.set(data, forKey: "tasks_v4")
        kvStore.synchronize()
        lastSyncDate = Date()
    }
    
    func loadTasks() -> [PlannerTask]? {
        guard let data = kvStore.data(forKey: "tasks_v4"),
              let tasks = try? JSONDecoder().decode([PlannerTask].self, from: data) else { return nil }
        return tasks
    }
    
    func saveWellness(_ snapshot: WellnessSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        kvStore.set(data, forKey: "wellness_v3")
        kvStore.synchronize()
    }
    
    func loadWellness() -> WellnessSnapshot? {
        guard let data = kvStore.data(forKey: "wellness_v3"),
              let snapshot = try? JSONDecoder().decode(WellnessSnapshot.self, from: data) else { return nil }
        return snapshot
    }
    
    func saveDayBounds(_ bounds: DayBounds) {
        kvStore.set(bounds.riseHour, forKey: "dayBounds_riseHour")
        kvStore.set(bounds.riseMinute, forKey: "dayBounds_riseMinute")
        kvStore.set(bounds.windDownHour, forKey: "dayBounds_windHour")
        kvStore.set(bounds.windDownMinute, forKey: "dayBounds_windMinute")
        kvStore.synchronize()
    }
    
    func loadDayBounds() -> DayBounds? {
        let rH = kvStore.object(forKey: "dayBounds_riseHour") as? Int
        let rM = kvStore.object(forKey: "dayBounds_riseMinute") as? Int
        let wH = kvStore.object(forKey: "dayBounds_windHour") as? Int
        let wM = kvStore.object(forKey: "dayBounds_windMinute") as? Int
        guard let riseH = rH, let riseM = rM, let windH = wH, let windM = wM else { return nil }
        return DayBounds(riseHour: riseH, riseMinute: riseM, windDownHour: windH, windDownMinute: windM)
    }
    
    func saveAIModel(_ model: AIModel) {
        kvStore.set(model.rawValue, forKey: "aiModel_v2")
        kvStore.synchronize()
    }
    
    func loadAIModel() -> AIModel? {
        guard let raw = kvStore.string(forKey: "aiModel_v2"),
              let model = AIModel(rawValue: raw) else { return nil }
        return model
    }

    func saveCategories(_ categories: [TaskCategory]) {
        guard let data = try? JSONEncoder().encode(categories) else { return }
        kvStore.set(data, forKey: "categories_v1")
        kvStore.synchronize()
    }

    func loadCategories() -> [TaskCategory]? {
        guard let data = kvStore.data(forKey: "categories_v1"),
              let list = try? JSONDecoder().decode([TaskCategory].self, from: data) else { return nil }
        return list
    }

    func saveTags(_ tags: [TaskTag]) {
        guard let data = try? JSONEncoder().encode(tags) else { return }
        kvStore.set(data, forKey: "tags_v1")
        kvStore.synchronize()
    }

    func loadTags() -> [TaskTag]? {
        guard let data = kvStore.data(forKey: "tags_v1"),
              let list = try? JSONDecoder().decode([TaskTag].self, from: data) else { return nil }
        return list
    }
    
    // MARK: - Force Sync
    
    func forceSync() {
        guard NetworkMonitor.shared.isConnected else {
            syncError = "Нет подключения к сети"
            return
        }
        
        isSyncing = true
        syncError = nil
        
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // Small delay for UI
            kvStore.synchronize()
            saveLastSyncDate()
            pendingChanges = 0
            isSyncing = false
            objectWillChange.send()
        }
    }
    
    // MARK: - Offline Queue
    
    func queueForSync(_ task: PlannerTask) {
        if NetworkMonitor.shared.isConnected {
            // Sync immediately
            forceSync()
        } else {
            // Queue for later
            pendingChanges += 1
        }
    }
}

struct WellnessSnapshot: Codable {
    var meals: [MealEntry]
    var sleep: [SleepEntry]
    var activities: [ActivityEntry]
}
