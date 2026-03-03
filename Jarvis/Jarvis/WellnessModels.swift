import Foundation
import Combine

// MARK: - Meal Source

enum MealSource: String, Codable, Hashable, CaseIterable, Sendable {
    case breakfast = "breakfast"
    case lunch = "lunch"
    case dinner = "dinner"
    case snack = "snack"
    
    var displayName: String {
        switch self {
        case .breakfast: return "Завтрак"
        case .lunch: return "Обед"
        case .dinner: return "Ужин"
        case .snack: return "Перекус"
        }
    }
    
    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.fill"
        case .snack: return "cup.and.saucer.fill"
        }
    }
}

// MARK: - Sleep Quality

enum SleepQuality: String, Codable, Hashable, CaseIterable, Sendable {
    case poor = "poor"
    case fair = "fair"
    case good = "good"
    case excellent = "excellent"
    
    var displayName: String {
        switch self {
        case .poor: return "Плохо"
        case .fair: return "Нормально"
        case .good: return "Хорошо"
        case .excellent: return "Отлично"
        }
    }
    
    var icon: String {
        switch self {
        case .poor: return "moon.zzz"
        case .fair: return "moon"
        case .good: return "moon.fill"
        case .excellent: return "moon.stars.fill"
        }
    }
    
    var numericValue: Int {
        switch self {
        case .poor: return 1
        case .fair: return 2
        case .good: return 3
        case .excellent: return 4
        }
    }
}

struct MealEntry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var calories: Int
    var date: Date
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var mealSource: MealSource?
    var notes: String
    
    init(id: UUID = UUID(), title: String, calories: Int, date: Date = Date(),
         protein: Double? = nil, carbs: Double? = nil, fat: Double? = nil,
         mealSource: MealSource? = nil, notes: String = "") {
        self.id = id
        self.title = title
        self.calories = calories
        self.date = date
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.mealSource = mealSource
        self.notes = notes
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, calories, date, protein, carbs, fat, mealSource, notes
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        calories = try c.decode(Int.self, forKey: .calories)
        date = try c.decode(Date.self, forKey: .date)
        protein = try c.decodeIfPresent(Double.self, forKey: .protein)
        carbs = try c.decodeIfPresent(Double.self, forKey: .carbs)
        fat = try c.decodeIfPresent(Double.self, forKey: .fat)
        mealSource = try c.decodeIfPresent(MealSource.self, forKey: .mealSource)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }
}

struct SleepEntry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var start: Date
    var end: Date
    var quality: SleepQuality?
    var notes: String
    
    init(id: UUID = UUID(), start: Date, end: Date, quality: SleepQuality? = nil, notes: String = "") {
        self.id = id
        self.start = start
        self.end = end
        self.quality = quality
        self.notes = notes
    }
    
    enum CodingKeys: String, CodingKey {
        case id, start, end, quality, notes
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        start = try c.decode(Date.self, forKey: .start)
        end = try c.decode(Date.self, forKey: .end)
        quality = try c.decodeIfPresent(SleepQuality.self, forKey: .quality)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }
    
    var hours: Double { end.timeIntervalSince(start) / 3600 }
}

struct ActivityEntry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var minutes: Int
    var date: Date
    var calories: Int?
    var notes: String
    
    init(id: UUID = UUID(), title: String, minutes: Int, date: Date = Date(), calories: Int? = nil, notes: String = "") {
        self.id = id
        self.title = title
        self.minutes = minutes
        self.date = date
        self.calories = calories
        self.notes = notes
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, minutes, date, calories, notes
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        minutes = try c.decode(Int.self, forKey: .minutes)
        date = try c.decode(Date.self, forKey: .date)
        calories = try c.decodeIfPresent(Int.self, forKey: .calories)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }
}

// MARK: - Water Tracking

struct WaterEntry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var glasses: Int
    var date: Date
    
    init(id: UUID = UUID(), glasses: Int = 1, date: Date = Date()) {
        self.id = id
        self.glasses = glasses
        self.date = date
    }
}

// MARK: - Wellness Goals

struct WellnessGoals: Codable, Hashable, Sendable {
    var dailyCalorieTarget: Int
    var dailyWaterGlasses: Int
    var dailySleepHours: Double
    var dailyActivityMinutes: Int
    var dailyProteinGrams: Double?
    var dailyCarbsGrams: Double?
    var dailyFatGrams: Double?
    
    init(dailyCalorieTarget: Int = 2000, dailyWaterGlasses: Int = 8,
         dailySleepHours: Double = 8.0, dailyActivityMinutes: Int = 30,
         dailyProteinGrams: Double? = nil, dailyCarbsGrams: Double? = nil,
         dailyFatGrams: Double? = nil) {
        self.dailyCalorieTarget = dailyCalorieTarget
        self.dailyWaterGlasses = dailyWaterGlasses
        self.dailySleepHours = dailySleepHours
        self.dailyActivityMinutes = dailyActivityMinutes
        self.dailyProteinGrams = dailyProteinGrams
        self.dailyCarbsGrams = dailyCarbsGrams
        self.dailyFatGrams = dailyFatGrams
    }
    
    static let `default` = WellnessGoals()
}

@MainActor
final class WellnessStore: ObservableObject {
    @Published var meals: [MealEntry] = []
    @Published var sleep: [SleepEntry] = []
    @Published var activities: [ActivityEntry] = []
    @Published var waterEntries: [WaterEntry] = []
    @Published var goals: WellnessGoals = .default
    
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
            if let water = snapshot.waterEntries { waterEntries = water }
            if let g = snapshot.goals { goals = g }
        }
    }
    
    var todayCalories: Int {
        meals.lazy
            .filter { Calendar.current.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.calories }
    }
    
    var todayProtein: Double {
        meals.lazy
            .filter { Calendar.current.isDateInToday($0.date) }
            .reduce(0.0) { $0 + ($1.protein ?? 0) }
    }
    
    var todayWaterGlasses: Int {
        waterEntries.lazy
            .filter { Calendar.current.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.glasses }
    }
    
    var todayActivityMinutes: Int {
        activities.lazy
            .filter { Calendar.current.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.minutes }
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
    
    func addWater(_ glasses: Int = 1) {
        waterEntries.append(WaterEntry(glasses: glasses))
        save()
    }
    
    func updateGoals(_ newGoals: WellnessGoals) {
        goals = newGoals
        save()
    }
    
    private func save() {
        let snapshot = WellnessSnapshot(meals: meals, sleep: sleep, activities: activities, waterEntries: waterEntries, goals: goals)
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
            if let water = snapshot.waterEntries { waterEntries = water }
            if let g = snapshot.goals { goals = g }
        } else if let data = UserDefaults.standard.data(forKey: Config.Storage.wellnessKey),
                  let snapshot = try? JSONDecoder().decode(WellnessSnapshot.self, from: data) {
            meals = snapshot.meals
            sleep = snapshot.sleep
            activities = snapshot.activities
            if let water = snapshot.waterEntries { waterEntries = water }
            if let g = snapshot.goals { goals = g }
        }
    }
}
