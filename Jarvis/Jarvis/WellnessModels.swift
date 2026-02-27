import Foundation
import Combine

struct MealEntry: Identifiable, Codable, Hashable {
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

struct SleepEntry: Identifiable, Codable, Hashable {
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

struct ActivityEntry: Identifiable, Codable, Hashable {
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

final class WellnessStore: ObservableObject {
    @Published var meals: [MealEntry] = []
    @Published var sleep: [SleepEntry] = []
    @Published var activities: [ActivityEntry] = []
    
    init() { load() }
    
    var todayCalories: Int {
        meals.filter { Calendar.current.isDateInToday($0.date) }
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
    
    private struct Snapshot: Codable {
        var meals: [MealEntry]
        var sleep: [SleepEntry]
        var activities: [ActivityEntry]
    }
    
    private func save() {
        let snapshot = Snapshot(meals: meals, sleep: sleep, activities: activities)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: Config.Storage.wellnessKey)
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Config.Storage.wellnessKey),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        meals = snapshot.meals
        sleep = snapshot.sleep
        activities = snapshot.activities
    }
}
