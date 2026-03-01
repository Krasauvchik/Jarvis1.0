import Foundation
import Combine

// MARK: - Repository Protocol

@MainActor
@preconcurrency
protocol Repository<Entity>: AnyObject where Entity: Identifiable {
    associatedtype Entity
    
    var items: [Entity] { get }
    var itemsPublisher: AnyPublisher<[Entity], Never> { get }
    
    func getAll() -> [Entity]
    func get(by id: Entity.ID) -> Entity?
    func add(_ item: Entity)
    func update(_ item: Entity)
    func delete(by id: Entity.ID)
    func save() throws
    func load() throws
}

// MARK: - Task Repository

@MainActor
final class TaskRepository: ObservableObject, Repository {
    typealias Entity = PlannerTask
    
    static let shared = TaskRepository()
    
    @Published private(set) var items: [PlannerTask] = []
    
    var itemsPublisher: AnyPublisher<[PlannerTask], Never> {
        $items.eraseToAnyPublisher()
    }
    
    private let storageKey = Config.Storage.tasksKey
    private let cloudSync = CloudSync.shared
    
    private init() {
        do {
            try load()
        } catch {
            Logger.shared.error(error, context: "Failed to load tasks")
        }
    }
    
    // MARK: - CRUD Operations
    
    func getAll() -> [PlannerTask] {
        items
    }
    
    func get(by id: UUID) -> PlannerTask? {
        items.first { $0.id == id }
    }
    
    func add(_ task: PlannerTask) {
        items.append(task)
        saveQuietly()
        Logger.shared.info("Task added: \(task.title)")
    }
    
    func update(_ task: PlannerTask) {
        guard let index = items.firstIndex(where: { $0.id == task.id }) else {
            Logger.shared.warning("Task not found for update: \(task.id)")
            return
        }
        items[index] = task
        saveQuietly()
        Logger.shared.info("Task updated: \(task.title)")
    }
    
    func delete(by id: UUID) {
        items.removeAll { $0.id == id }
        saveQuietly()
        Logger.shared.info("Task deleted: \(id)")
    }
    
    // MARK: - Persistence
    
    func save() throws {
        // Local storage
        guard let data = try? JSONEncoder().encode(items) else {
            throw StorageError.saveFailed
        }
        UserDefaults.standard.set(data, forKey: storageKey)
        
        // Cloud sync
        cloudSync.saveTasks(items)
        
        Logger.shared.debug("Tasks saved: \(items.count) items")
    }
    
    func load() throws {
        // Try cloud first
        if let cloudTasks = cloudSync.loadTasks() {
            items = cloudTasks
            Logger.shared.debug("Tasks loaded from cloud: \(items.count) items")
            return
        }
        
        // Fallback to local
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            Logger.shared.debug("No tasks found in storage")
            return
        }
        
        guard let tasks = try? JSONDecoder().decode([PlannerTask].self, from: data) else {
            throw StorageError.loadFailed
        }
        
        items = tasks
        Logger.shared.debug("Tasks loaded from local: \(items.count) items")
    }
    
    private func saveQuietly() {
        try? save()
    }
    
    // MARK: - Query Methods
    
    func tasks(for date: Date) -> [PlannerTask] {
        let calendar = Calendar.current
        return items.filter { 
            !$0.isInbox && calendar.isDate($0.date, inSameDayAs: date) 
        }.sorted { $0.date < $1.date }
    }
    
    func inboxTasks() -> [PlannerTask] {
        items.filter { $0.isInbox && !$0.isCompleted }
            .sorted { $0.date < $1.date }
    }
    
    func completedTasks() -> [PlannerTask] {
        items.filter { $0.isCompleted }
            .sorted { $0.date > $1.date }
    }
    
    func overdueTasks() -> [PlannerTask] {
        let now = Date()
        return items.filter { 
            !$0.isCompleted && !$0.isInbox && $0.date < now 
        }.sorted { $0.date < $1.date }
    }
    
    func upcomingTasks(days: Int = 7) -> [PlannerTask] {
        let calendar = Calendar.current
        guard let endDate = calendar.date(byAdding: .day, value: days, to: Date()) else {
            return []
        }
        
        return items.filter {
            !$0.isCompleted && !$0.isInbox && $0.date >= Date() && $0.date <= endDate
        }.sorted { $0.date < $1.date }
    }
    
    // MARK: - Statistics
    
    func statistics() -> TaskStatistics {
        TaskStatistics(
            total: items.count,
            completed: items.filter { $0.isCompleted }.count,
            inbox: items.filter { $0.isInbox && !$0.isCompleted }.count,
            overdue: overdueTasks().count
        )
    }
}

// MARK: - Task Statistics

struct TaskStatistics {
    let total: Int
    let completed: Int
    let inbox: Int
    let overdue: Int
    
    var completionRate: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
    
    var pending: Int {
        total - completed
    }
}

// MARK: - Wellness Repository

@MainActor
final class WellnessRepository: ObservableObject {
    static let shared = WellnessRepository()
    
    @Published private(set) var meals: [MealEntry] = []
    @Published private(set) var sleepEntries: [SleepEntry] = []
    @Published private(set) var activities: [ActivityEntry] = []
    
    private let storageKey = Config.Storage.wellnessKey
    private let cloudSync = CloudSync.shared
    
    private init() {
        load()
    }
    
    // MARK: - Meals
    
    func addMeal(_ meal: MealEntry) {
        meals.append(meal)
        save()
    }
    
    func todayCalories() -> Int {
        let calendar = Calendar.current
        return meals
            .filter { calendar.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.calories }
    }
    
    // MARK: - Sleep
    
    func addSleep(_ entry: SleepEntry) {
        sleepEntries.append(entry)
        save()
    }
    
    func lastNightSleep() -> SleepEntry? {
        sleepEntries
            .sorted(by: { $0.start > $1.start })
            .first
    }
    
    // MARK: - Activities
    
    func addActivity(_ activity: ActivityEntry) {
        activities.append(activity)
        save()
    }
    
    // MARK: - Persistence
    
    private func save() {
        let snapshot = WellnessSnapshot(
            meals: meals,
            sleep: sleepEntries,
            activities: activities
        )
        cloudSync.saveWellness(snapshot)
        
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func load() {
        if let snapshot = cloudSync.loadWellness() {
            meals = snapshot.meals
            sleepEntries = snapshot.sleep
            activities = snapshot.activities
            return
        }
        
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let snapshot = try? JSONDecoder().decode(WellnessSnapshot.self, from: data) {
            meals = snapshot.meals
            sleepEntries = snapshot.sleep
            activities = snapshot.activities
        }
    }
}
