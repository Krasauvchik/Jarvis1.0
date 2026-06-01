import Foundation

/// Direct Google Gemini API client for iOS.
/// Uses Gemini 2.0 Flash free tier — 1500 requests/day, 1M+ tokens/min.
/// No backend required. Works in Russia via API.
///
/// Free tier docs: https://ai.google.dev/pricing
final class GeminiService: @unchecked Sendable {
    static let shared = GeminiService()

    // MARK: - Configuration

    /// User-provided Gemini API key, stored securely in the Keychain.
    ///
    /// There is intentionally no built-in/shared key: a key embedded in the app
    /// binary is extractable by anyone and would be abused, rate-limited, and
    /// ultimately revoked. Users supply their own free key in Settings.
    /// Get one at https://aistudio.google.com/apikey
    var apiKey: String {
        SecretStore.get(.geminiAPIKey) ?? ""
    }

    var isConfigured: Bool {
        !apiKey.isEmpty
    }

    /// Currently selected Gemini model
    var modelName: String {
        UserDefaults.standard.string(forKey: Config.Storage.geminiModelKey) ?? Model.flash.rawValue
    }

    // MARK: - Models

    enum Model: String, CaseIterable, Identifiable {
        case flash = "gemini-2.5-flash"
        case flashLite = "gemini-2.0-flash-lite"
        case pro = "gemini-2.5-pro"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .flash: return "Gemini 2.5 Flash"
            case .flashLite: return "Gemini 2.0 Flash Lite"
            case .pro: return "Gemini 2.5 Pro"
            }
        }

        var descriptionText: String {
            switch self {
            case .flash: return "Быстрая, бесплатная, 1M контекст. Рекомендуется."
            case .flashLite: return "Самая быстрая и дешёвая. Для простых задач."
            case .pro: return "Максимальное качество. Бесплатно 50 запросов/день."
            }
        }

        var freeTierLimit: String {
            switch self {
            case .flash: return "1500 запросов/день"
            case .flashLite: return "1500 запросов/день"
            case .pro: return "50 запросов/день"
            }
        }
    }

    // MARK: - API Structures

    private struct GeminiRequest: Encodable {
        let contents: [Content]
        let systemInstruction: SystemInstruction?
        let generationConfig: GenerationConfig?

        struct Content: Encodable {
            let role: String
            let parts: [Part]
        }

        struct Part: Encodable {
            let text: String
        }

        struct SystemInstruction: Encodable {
            let parts: [Part]
        }

        struct GenerationConfig: Encodable {
            let temperature: Double?
            let maxOutputTokens: Int?
            let responseMimeType: String?
        }
    }

    private struct GeminiResponse: Decodable {
        let candidates: [Candidate]?
        let error: GeminiError?

        struct Candidate: Decodable {
            let content: Content?
            let finishReason: String?
        }

        struct Content: Decodable {
            let parts: [Part]?
            let role: String?
        }

        struct Part: Decodable {
            let text: String?
        }

        struct GeminiError: Decodable {
            let code: Int?
            let message: String?
            let status: String?
        }
    }

    private init() {}

    // MARK: - Public API

    /// Generate a response from Gemini.
    func generate(
        message: String,
        systemPrompt: String? = nil,
        temperature: Double = 0.3,
        maxTokens: Int = 2000
    ) async -> String? {
        guard isConfigured else {
            Logger.shared.warning("Gemini: API key not configured")
            return nil
        }

        let model = modelName
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent") else {
            return nil
        }

        var request = buildRequest(
            url: url,
            messages: [("user", message)],
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        return await executeRequest(request)
    }

    /// Chat with message history.
    func chat(
        messages: [(role: String, content: String)],
        systemPrompt: String? = nil,
        temperature: Double = 0.3,
        maxTokens: Int = 2000
    ) async -> String? {
        guard isConfigured else { return nil }

        let model = modelName
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent") else {
            return nil
        }

        var request = buildRequest(
            url: url,
            messages: messages,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        return await executeRequest(request)
    }

    // MARK: - Private

    // Thread-safe: each call creates its own coder (lightweight objects)
    private func makeEncoder() -> JSONEncoder { JSONEncoder() }
    private func makeDecoder() -> JSONDecoder { JSONDecoder() }

    private func buildRequest(
        url: URL,
        messages: [(role: String, content: String)],
        systemPrompt: String?,
        temperature: Double,
        maxTokens: Int
    ) -> URLRequest {
        // Map roles: "assistant" → "model" for Gemini API
        let contents = messages.map { msg in
            GeminiRequest.Content(
                role: msg.0 == "assistant" ? "model" : "user",
                parts: [.init(text: msg.1)]
            )
        }

        let systemInstruction: GeminiRequest.SystemInstruction?
        if let sys = systemPrompt, !sys.isEmpty {
            systemInstruction = .init(parts: [.init(text: sys)])
        } else {
            systemInstruction = nil
        }

        let payload = GeminiRequest(
            contents: contents,
            systemInstruction: systemInstruction,
            generationConfig: .init(
                temperature: temperature,
                maxOutputTokens: maxTokens,
                responseMimeType: nil
            )
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30  // Allow more time for Gemini responses
        request.httpBody = try? makeEncoder().encode(payload)
        return request
    }

    private func executeRequest(_ request: URLRequest) async -> String? {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                Logger.shared.warning("Gemini: invalid response type")
                return nil
            }

            guard (200...299).contains(http.statusCode) else {
                if let body = String(data: data, encoding: .utf8) {
                    Logger.shared.warning("Gemini: HTTP \(http.statusCode): \(body.prefix(200))")
                }
                return nil
            }

            let decoded = try makeDecoder().decode(GeminiResponse.self, from: data)

            if let error = decoded.error {
                Logger.shared.warning("Gemini API error: \(error.message ?? "unknown")")
                return nil
            }

            guard let text = decoded.candidates?.first?.content?.parts?.first?.text,
                  !text.isEmpty else {
                Logger.shared.warning("Gemini: empty response")
                return nil
            }

            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            Logger.shared.warning("Gemini request failed: \(error.localizedDescription)")
            return nil
        }
    }
}
