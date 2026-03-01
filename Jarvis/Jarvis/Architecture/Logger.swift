import Foundation
import os.log

// MARK: - Log Level

enum LogLevel: Int, Comparable, Sendable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case critical = 4
    
    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🔥"
        }
    }
    
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }
    
    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Log Entry

struct LogEntry: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let message: String
    let file: String
    let function: String
    let line: Int
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
    
    var shortFile: String {
        (file as NSString).lastPathComponent
    }
}

// MARK: - Logger

final class Logger: @unchecked Sendable {
    static let shared = Logger()
    
    private let osLog = OSLog(subsystem: "com.jarvis.app", category: "general")
    private let queue = DispatchQueue(label: "com.jarvis.logger", qos: .utility)
    
    private var entries: [LogEntry] = []
    private let maxEntries = 1000
    
    #if DEBUG
    var minimumLevel: LogLevel = .debug
    var isConsoleEnabled = true
    #else
    var minimumLevel: LogLevel = .warning
    var isConsoleEnabled = false
    #endif
    
    private init() {}
    
    // MARK: - Logging Methods
    
    func debug(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(.debug, message(), file: file, function: function, line: line)
    }
    
    func info(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(.info, message(), file: file, function: function, line: line)
    }
    
    func warning(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(.warning, message(), file: file, function: function, line: line)
    }
    
    func error(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(.error, message(), file: file, function: function, line: line)
    }
    
    func critical(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(.critical, message(), file: file, function: function, line: line)
    }
    
    // MARK: - Error Logging
    
    func error(
        _ error: Error,
        context: String? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let message = context != nil 
            ? "\(context!): \(error.localizedDescription)"
            : error.localizedDescription
        log(.error, message, file: file, function: function, line: line)
    }
    
    // MARK: - Core Logging
    
    private func log(
        _ level: LogLevel,
        _ message: String,
        file: String,
        function: String,
        line: Int
    ) {
        guard level >= minimumLevel else { return }
        
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            message: message,
            file: file,
            function: function,
            line: line
        )
        
        queue.async { [weak self] in
            self?.storeEntry(entry)
            self?.outputToConsole(entry)
            self?.outputToOSLog(entry)
        }
    }
    
    private func storeEntry(_ entry: LogEntry) {
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }
    
    private func outputToConsole(_ entry: LogEntry) {
        guard isConsoleEnabled else { return }
        
        let output = "\(entry.level.emoji) [\(entry.formattedTimestamp)] [\(entry.shortFile):\(entry.line)] \(entry.message)"
        print(output)
    }
    
    private func outputToOSLog(_ entry: LogEntry) {
        os_log("%{public}@", log: osLog, type: entry.level.osLogType, entry.message)
    }
    
    // MARK: - Log Access
    
    func getEntries(level: LogLevel? = nil, limit: Int = 100) -> [LogEntry] {
        queue.sync {
            var result = entries
            if let level = level {
                result = result.filter { $0.level >= level }
            }
            return Array(result.suffix(limit))
        }
    }
    
    func clear() {
        queue.async { [weak self] in
            self?.entries.removeAll()
        }
    }
    
    // MARK: - Export
    
    func exportLogs() -> String {
        queue.sync {
            entries.map { entry in
                "[\(entry.formattedTimestamp)] [\(entry.level)] [\(entry.shortFile):\(entry.line)] \(entry.message)"
            }.joined(separator: "\n")
        }
    }
}

// MARK: - Performance Logging

extension Logger {
    func measureTime<T>(
        _ operation: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        block: () throws -> T
    ) rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        defer {
            let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
            debug("⏱ \(operation) completed in \(String(format: "%.2f", elapsed))ms", file: file, function: function, line: line)
        }
        return try block()
    }
    
    func measureTimeAsync<T>(
        _ operation: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        block: () async throws -> T
    ) async rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        defer {
            let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
            debug("⏱ \(operation) completed in \(String(format: "%.2f", elapsed))ms", file: file, function: function, line: line)
        }
        return try await block()
    }
}

// MARK: - Convenience Global Functions

func logDebug(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.debug(message(), file: file, function: function, line: line)
}

func logInfo(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.info(message(), file: file, function: function, line: line)
}

func logWarning(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.warning(message(), file: file, function: function, line: line)
}

func logError(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.error(message(), file: file, function: function, line: line)
}

func logError(_ error: Error, context: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.error(error, context: context, file: file, function: function, line: line)
}
