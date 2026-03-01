import Foundation
import Combine

struct MealEntry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var calories: Int
    var date: Date
    
    init(id: UUID = UUID(), title: String, calories: Int, date: Date = Date()) {
        self.id = id
        self.title = title
        self.calories = calories
        self.date = date
    }
}

struct SleepEntry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var start: Date
    var end: Date
    
    init(id: UUID = UUID(), start: Date, end: Date) {
        self.id = id
        self.start = start
        self.end = end
    }
    
    var hours: Double { end.timeIntervalSince(start) / 3600 }
}

struct ActivityEntry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var minutes: Int
    var date: Date
    
    init(id: UUID = UUID(), title: String, minutes: Int, date: Date = Date()) {
        self.id = id
        self.title = title
        self.minutes = minutes
        self.date = date
    }
}

@MainActor
final class WellnessStore: ObservableObject {
    @Published var meals: [MealEntry] = []
    @Published var sleep: [SleepEntry] = []
    @Published var activities: [ActivityEntry] = []
    
    private var syncObserver: NSObjectProtocol?
    
    init() {
        load()
        setupCloudSync()
    }
    
    deinit {
        if let observer = syncObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupCloudSync() {
        syncObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] _ in
            let store = self
            Task { @MainActor in
                store?.loadFromCloud()
            }
        }
    }
    
    private func loadFromCloud() {
        if let snapshot = CloudSync.shared.loadWellness() {
            meals = snapshot.meals
            sleep = snapshot.sleep
            activities = snapshot.activities
        }
    }
    
    var todayCalories: Int {
        meals.lazy
            .filter { Calendar.current.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.calories }
    }
    
    func addMeal(_ meal: MealEntry) {
        meals.append(meal)
        meals.sort { $0.date < $1.date }
        save()
    }
    
    func addSleep(_ entry: SleepEntry) {
        sleep.append(entry)
        sleep.sort { $0.start < $1.start }
        save()
    }
    
    func addActivity(_ entry: ActivityEntry) {
        activities.append(entry)
        activities.sort { $0.date < $1.date }
        save()
    }
    
    private func save() {
        let snapshot = WellnessSnapshot(meals: meals, sleep: sleep, activities: activities)
        CloudSync.shared.saveWellness(snapshot)
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: Config.Storage.wellnessKey)
        }
    }
    
    private func load() {
        if let snapshot = CloudSync.shared.loadWellness() {
            meals = snapshot.meals
            sleep = snapshot.sleep
            activities = snapshot.activities
        } else if let data = UserDefaults.standard.data(forKey: Config.Storage.wellnessKey),
                  let snapshot = try? JSONDecoder().decode(WellnessSnapshot.self, from: data) {
            meals = snapshot.meals
            sleep = snapshot.sleep
            activities = snapshot.activities
        }
    }
}
