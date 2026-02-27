import Foundation
import Combine

struct PlannerTask: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var notes: String
    var date: Date
    var isCompleted: Bool
    var hasAlarm: Bool
    
    init(id: UUID = UUID(), title: String, notes: String = "", date: Date, isCompleted: Bool = false, hasAlarm: Bool = true) {
        self.id = id
        self.title = title
        self.notes = notes
        self.date = date
        self.isCompleted = isCompleted
        self.hasAlarm = hasAlarm
    }
}

final class PlannerStore: ObservableObject {
    @Published var tasks: [PlannerTask] = [] {
        didSet { save() }
    }
    
    init() { load() }
    
    func add(_ task: PlannerTask) {
        tasks.append(task)
        tasks.sort { $0.date < $1.date }
    }
    
    func update(_ task: PlannerTask) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx] = task
        tasks.sort { $0.date < $1.date }
    }
    
    func remove(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            tasks.remove(at: index)
        }
    }
    
    private func save() {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        UserDefaults.standard.set(data, forKey: Config.Storage.tasksKey)
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Config.Storage.tasksKey),
              let decoded = try? JSONDecoder().decode([PlannerTask].self, from: data) else { return }
        tasks = decoded
    }
}
