import Foundation
import Combine

final class AIManager: ObservableObject {
    @Published var selectedModel: AIModel {
        didSet { saveModel() }
    }
    
    private let adapters: [AIModel: AIAdapter] = [
        .heuristic: HeuristicAdapter(),
        .onDeviceLarge: OnDeviceLargeAdapter(),
        .cloudGPT: CloudGPTAdapter()
    ]
    
    init() {
        if let data = UserDefaults.standard.data(forKey: Config.Storage.aiModelKey),
           let model = try? JSONDecoder().decode(AIModel.self, from: data) {
            selectedModel = model
        } else {
            selectedModel = .heuristic
        }
    }
    
    func extractTask(from input: String, referenceDate: Date) -> PlannerTask? {
        adapters[selectedModel]?.extractTask(from: input, referenceDate: referenceDate)
    }
    
    func generateAdvice(from tasks: [PlannerTask]) -> [String] {
        adapters[selectedModel]?.generateAdvice(from: tasks) ?? []
    }
    
    func generateLLMAdvice(from tasks: [PlannerTask]) async -> String? {
        guard !tasks.isEmpty else { return nil }
        
        struct TaskDTO: Encodable { let title: String; let notes: String; let date: Date; let isCompleted: Bool }
        struct Payload: Encodable { let tasks: [TaskDTO] }
        struct Response: Decodable { let advice: String }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        var request = URLRequest(url: Config.Endpoints.llmPlan)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
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
        if let data = try? JSONEncoder().encode(selectedModel) {
            UserDefaults.standard.set(data, forKey: Config.Storage.aiModelKey)
        }
    }
}
