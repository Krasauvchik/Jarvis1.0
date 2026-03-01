import Foundation
import SwiftUI
import Combine

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
        case .noConnection: return "Нет подключения к интернету"
        case .invalidURL: return "Неверный URL"
        case .invalidResponse: return "Неверный ответ сервера"
        case .httpError(let code, let message): return "Ошибка HTTP \(code): \(message ?? "Неизвестная ошибка")"
        case .decodingError: return "Ошибка обработки данных"
        case .timeout: return "Превышено время ожидания"
        case .serverError(let message): return "Ошибка сервера: \(message)"
        case .unauthorized: return "Требуется авторизация"
        case .unknown(let error): return error.localizedDescription
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .noConnection, .timeout, .serverError: return true
        default: return false
        }
    }
}

// MARK: - App Error Types

/// Unified error type for the entire application
enum AppError: Error, LocalizedError, Identifiable, Sendable {
    case network(NetworkError)
    case sync(SyncError)
    case validation(ValidationError)
    case storage(StorageError)
    case auth(AuthError)
    case ai(AIError)
    case unknown(String)
    
    var id: String { localizedDescription }
    
    var errorDescription: String? {
        switch self {
        case .network(let error): return error.errorDescription
        case .sync(let error): return error.errorDescription
        case .validation(let error): return error.errorDescription
        case .storage(let error): return error.errorDescription
        case .auth(let error): return error.errorDescription
        case .ai(let error): return error.errorDescription
        case .unknown(let message): return message
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .network(.noConnection):
            return "Проверьте подключение к интернету и попробуйте снова"
        case .network(.timeout):
            return "Сервер не отвечает. Попробуйте позже"
        case .auth(.unauthorized):
            return "Войдите в аккаунт заново"
        case .sync(.conflict):
            return "Обновите данные и попробуйте снова"
        default:
            return "Попробуйте позже или обратитесь в поддержку"
        }
    }
    
    var icon: String {
        switch self {
        case .network: return "wifi.slash"
        case .sync: return "arrow.triangle.2.circlepath.circle"
        case .validation: return "exclamationmark.triangle"
        case .storage: return "externaldrive.badge.xmark"
        case .auth: return "lock.shield"
        case .ai: return "brain"
        case .unknown: return "questionmark.circle"
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .network(let error): return error.isRetryable
        case .sync: return true
        case .auth: return false
        default: return false
        }
    }
}

// MARK: - Sync Error

enum SyncError: Error, LocalizedError, Sendable {
    case conflict
    case dataCorrupted
    case cloudUnavailable
    case quotaExceeded
    
    var errorDescription: String? {
        switch self {
        case .conflict: return "Конфликт синхронизации"
        case .dataCorrupted: return "Данные повреждены"
        case .cloudUnavailable: return "iCloud недоступен"
        case .quotaExceeded: return "Превышен лимит хранилища"
        }
    }
}

// MARK: - Validation Error

enum ValidationError: Error, LocalizedError, Sendable {
    case emptyTitle
    case invalidDate
    case invalidDuration
    case tooManyTasks
    case custom(String)
    
    var errorDescription: String? {
        switch self {
        case .emptyTitle: return "Название не может быть пустым"
        case .invalidDate: return "Неверная дата"
        case .invalidDuration: return "Неверная длительность"
        case .tooManyTasks: return "Слишком много задач"
        case .custom(let message): return message
        }
    }
}

// MARK: - Storage Error

enum StorageError: Error, LocalizedError, Sendable {
    case saveFailed
    case loadFailed
    case migrationFailed
    case insufficientSpace
    
    var errorDescription: String? {
        switch self {
        case .saveFailed: return "Не удалось сохранить данные"
        case .loadFailed: return "Не удалось загрузить данные"
        case .migrationFailed: return "Ошибка миграции данных"
        case .insufficientSpace: return "Недостаточно места"
        }
    }
}

// MARK: - Auth Error

enum AuthError: Error, LocalizedError, Sendable {
    case unauthorized
    case tokenExpired
    case accountNotFound
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Требуется авторизация"
        case .tokenExpired: return "Сессия истекла"
        case .accountNotFound: return "Аккаунт не найден"
        case .permissionDenied: return "Доступ запрещён"
        }
    }
}

// MARK: - AI Error

enum AIError: Error, LocalizedError, Sendable {
    case modelUnavailable
    case inputTooLong
    case rateLimited
    case processingFailed
    
    var errorDescription: String? {
        switch self {
        case .modelUnavailable: return "AI модель недоступна"
        case .inputTooLong: return "Слишком длинный запрос"
        case .rateLimited: return "Превышен лимит запросов"
        case .processingFailed: return "Ошибка обработки"
        }
    }
}

// MARK: - Error Handler

@MainActor
final class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()
    
    @Published private(set) var currentError: AppError?
    @Published var showingError = false
    
    private init() {}
    
    func handle(_ error: Error, context: String? = nil) {
        let appError: AppError
        
        if let networkError = error as? NetworkError {
            appError = .network(networkError)
        } else if let syncError = error as? SyncError {
            appError = .sync(syncError)
        } else if let validationError = error as? ValidationError {
            appError = .validation(validationError)
        } else if let existingAppError = error as? AppError {
            appError = existingAppError
        } else {
            appError = .unknown(error.localizedDescription)
        }
        
        currentError = appError
        showingError = true
        
        // Log error
        Logger.shared.error(error, context: context)
    }
    
    func dismiss() {
        showingError = false
        currentError = nil
    }
}

// MARK: - Error Alert View Modifier

struct ErrorAlertModifier: ViewModifier {
    @ObservedObject var handler = ErrorHandler.shared
    
    func body(content: Content) -> some View {
        content
            .alert(
                "Ошибка",
                isPresented: $handler.showingError,
                presenting: handler.currentError
            ) { error in
                Button("OK") {
                    handler.dismiss()
                }
                if error.isRetryable {
                    Button("Повторить") {
                        // Retry logic would go here
                        handler.dismiss()
                    }
                }
            } message: { error in
                VStack {
                    Text(error.localizedDescription)
                    if let suggestion = error.recoverySuggestion {
                        Text(suggestion)
                            .font(.caption)
                    }
                }
            }
    }
}

extension View {
    func withErrorHandling() -> some View {
        modifier(ErrorAlertModifier())
    }
}

// MARK: - Result Extension

extension Result where Failure == Error {
    func appError() -> AppError? {
        switch self {
        case .success:
            return nil
        case .failure(let error):
            if let appError = error as? AppError {
                return appError
            }
            return .unknown(error.localizedDescription)
        }
    }
}
