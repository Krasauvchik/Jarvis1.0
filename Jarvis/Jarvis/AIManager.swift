import Foundation
import Combine

@MainActor
final class AIManager: ObservableObject {
    @Published var selectedModel: AIModel {
        didSet { saveModel() }
    }
    
    private let heuristic = HeuristicAdapter()
    private var syncObserver: NSObjectProtocol?
    
    init() {
        if let model = CloudSync.shared.loadAIModel() {
            selectedModel = model
        } else if let data = UserDefaults.standard.data(forKey: Config.Storage.aiModelKey),
                  let model = try? JSONDecoder().decode(AIModel.self, from: data) {
            selectedModel = model
        } else {
            selectedModel = .gemini
        }
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
            let service = self
            Task { @MainActor in
                guard let service else { return }
                if let model = CloudSync.shared.loadAIModel() {
                    service.selectedModel = model
                }
            }
        }
    }
    
    func extractTask(from input: String, referenceDate: Date) -> PlannerTask? {
        heuristic.extractTask(from: input, referenceDate: referenceDate)
    }
    
    func generateAdvice(from tasks: [PlannerTask]) -> [String] {
        heuristic.generateAdvice(from: tasks)
    }
    
    func generateLLMAdvice(from tasks: [PlannerTask]) async -> String? {
        guard !tasks.isEmpty else { return nil }
        
        struct TaskDTO: Encodable { let title: String; let notes: String; let date: Date; let isCompleted: Bool }
        struct Payload: Encodable { let tasks: [TaskDTO] }
        struct Response: Decodable { let advice: String }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let url = Config.Endpoints.llmPlan
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        
        let payload = Payload(tasks: tasks.map { TaskDTO(title: $0.title, notes: $0.notes, date: $0.date, isCompleted: $0.isCompleted) })
        request.httpBody = try? encoder.encode(payload)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try? JSONDecoder().decode(Response.self, from: data).advice
        } catch {
            return nil
        }
    }
    
    private func saveModel() {
        CloudSync.shared.saveAIModel(selectedModel)
        if let data = try? JSONEncoder().encode(selectedModel) {
            UserDefaults.standard.set(data, forKey: Config.Storage.aiModelKey)
        }
    }
}
