import Foundation

// MARK: - Network Error Types

enum NetworkError: Error, LocalizedError, Sendable {
    case noConnection
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case timeout
    case serverError(String)
    case unauthorized
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "Нет подключения к интернету"
        case .invalidURL:
            return "Неверный URL"
        case .invalidResponse:
            return "Неверный ответ сервера"
        case .httpError(let code, let message):
            return "Ошибка HTTP \(code): \(message ?? "Неизвестная ошибка")"
        case .decodingError:
            return "Ошибка обработки данных"
        case .timeout:
            return "Превышено время ожидания"
        case .serverError(let message):
            return "Ошибка сервера: \(message)"
        case .unauthorized:
            return "Требуется авторизация"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .noConnection, .timeout, .serverError:
            return true
        default:
            return false
        }
    }
}

// MARK: - Network Client

actor NetworkClient {
    static let shared = NetworkClient()
    
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private var cache: [String: CachedResponse] = [:]
    
    private struct CachedResponse {
        let data: Data
        let timestamp: Date
        let maxAge: TimeInterval
        
        var isValid: Bool {
            Date().timeIntervalSince(timestamp) < maxAge
        }
    }
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        config.requestCachePolicy = .returnCacheDataElseLoad
        
        session = URLSession(configuration: config)
        
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
    }
    
    // MARK: - GET Request
    
    func get<T: Decodable>(
        _ url: URL,
        headers: [String: String] = [:],
        cacheMaxAge: TimeInterval? = nil
    ) async throws -> T {
        // Check cache
        let cacheKey = url.absoluteString
        if let cachedResponse = cache[cacheKey], cachedResponse.isValid {
            await MainActor.run { Logger.shared.debug("Cache hit for \(url.path)") }
            return try decoder.decode(T.self, from: cachedResponse.data)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        let data = try await execute(request)
        
        // Cache response
        if let maxAge = cacheMaxAge {
            cache[cacheKey] = CachedResponse(data: data, timestamp: Date(), maxAge: maxAge)
        }
        
        return try decoder.decode(T.self, from: data)
    }
    
    // MARK: - POST Request
    
    func post<T: Decodable, B: Encodable>(
        _ url: URL,
        body: B,
        headers: [String: String] = [:]
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        let data = try await execute(request)
        return try decoder.decode(T.self, from: data)
    }
    
    // MARK: - POST with raw data
    
    func postData<T: Decodable>(
        _ url: URL,
        data: Data,
        contentType: String = "application/octet-stream"
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        
        let responseData = try await execute(request)
        return try decoder.decode(T.self, from: responseData)
    }
    
    // MARK: - Execute with Retry
    
    private func execute(_ request: URLRequest, retryCount: Int = 3) async throws -> Data {
        // Check network
        guard await MainActor.run(body: { NetworkMonitor.shared.isConnected }) else {
            throw NetworkError.noConnection
        }
        
        var lastError: Error?
        
        for attempt in 0..<retryCount {
            do {
                await MainActor.run {
                    Logger.shared.debug("Request: \(request.httpMethod ?? "GET") \(request.url?.path ?? "")")
                }
                
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                await MainActor.run {
                    Logger.shared.debug("Response: \(httpResponse.statusCode) for \(request.url?.path ?? "")")
                }
                
                switch httpResponse.statusCode {
                case 200...299:
                    return data
                case 401:
                    throw NetworkError.unauthorized
                case 500...599:
                    throw NetworkError.serverError("Server error \(httpResponse.statusCode)")
                default:
                    let message = String(data: data, encoding: .utf8)
                    throw NetworkError.httpError(statusCode: httpResponse.statusCode, message: message)
                }
            } catch let error as NetworkError {
                lastError = error
                if error.isRetryable && attempt < retryCount - 1 {
                    let delay = pow(2.0, Double(attempt)) // Exponential backoff
                    await MainActor.run {
                        Logger.shared.warning("Retrying in \(delay)s: \(error.localizedDescription)")
                    }
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                throw error
            } catch let error as URLError {
                lastError = error
                switch error.code {
                case .timedOut:
                    throw NetworkError.timeout
                case .notConnectedToInternet, .networkConnectionLost:
                    throw NetworkError.noConnection
                default:
                    throw NetworkError.unknown(error)
                }
            } catch {
                throw NetworkError.unknown(error)
            }
        }
        
        throw lastError ?? NetworkError.unknown(NSError(domain: "Unknown", code: -1))
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        cache.removeAll()
        Task { @MainActor in
            Logger.shared.info("Network cache cleared")
        }
    }
    
    func clearCache(for url: URL) {
        cache.removeValue(forKey: url.absoluteString)
    }
}

// MARK: - Request Builder (Fluent API)

struct RequestBuilder {
    private var url: URL
    private var method: String = "GET"
    private var headers: [String: String] = [:]
    private var body: Data?
    private var timeout: TimeInterval = 30
    
    init(url: URL) {
        self.url = url
    }
    
    init(endpoint: URL) {
        self.url = endpoint
    }
    
    func method(_ method: String) -> RequestBuilder {
        var copy = self
        copy.method = method
        return copy
    }
    
    func header(_ key: String, _ value: String) -> RequestBuilder {
        var copy = self
        copy.headers[key] = value
        return copy
    }
    
    func body<T: Encodable>(_ body: T) -> RequestBuilder {
        var copy = self
        copy.body = try? JSONEncoder().encode(body)
        copy.headers["Content-Type"] = "application/json"
        return copy
    }
    
    func timeout(_ seconds: TimeInterval) -> RequestBuilder {
        var copy = self
        copy.timeout = seconds
        return copy
    }
    
    func build() -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = timeout
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return request
    }
}
