import Foundation
import Combine
import os.log

// MARK: - Performance Tracker

/// Lightweight in-app performance monitoring.
/// Tracks view load times, network requests, and custom spans.
@MainActor
final class PerformanceTracker: ObservableObject {
    static let shared = PerformanceTracker()
    
    private var spans: [String: CFAbsoluteTime] = [:]
    @Published private(set) var metrics: [PerformanceMetric] = []
    
    private let maxMetrics = 500
    private let logger = os.Logger(subsystem: "com.jarvis.planner", category: "Performance")
    
    private init() {}
    
    /// Start timing a named span.
    func startSpan(_ name: String) {
        spans[name] = CFAbsoluteTimeGetCurrent()
    }
    
    /// End a span and record the metric.
    @discardableResult
    func endSpan(_ name: String) -> TimeInterval? {
        guard let start = spans.removeValue(forKey: name) else { return nil }
        let duration = CFAbsoluteTimeGetCurrent() - start
        let metric = PerformanceMetric(name: name, duration: duration, timestamp: Date())
        
        metrics.append(metric)
        if metrics.count > maxMetrics {
            metrics.removeFirst(metrics.count - maxMetrics)
        }
        
        if duration > 1.0 {
            logger.warning("Slow operation: \(name) took \(String(format: "%.2f", duration))s")
        } else {
            logger.debug("\(name): \(String(format: "%.3f", duration))s")
        }
        
        return duration
    }
    
    /// Measure a synchronous block.
    func measure<T>(_ name: String, block: () throws -> T) rethrows -> T {
        startSpan(name)
        let result = try block()
        endSpan(name)
        return result
    }
    
    /// Average duration for a named metric.
    func averageDuration(for name: String) -> TimeInterval? {
        let matching = metrics.filter { $0.name == name }
        guard !matching.isEmpty else { return nil }
        return matching.reduce(0) { $0 + $1.duration } / Double(matching.count)
    }
    
    /// Clear all metrics.
    func reset() {
        metrics.removeAll()
        spans.removeAll()
    }
    
    /// Record a pre-built metric directly.
    func record(_ metric: PerformanceMetric) {
        metrics.append(metric)
        if metrics.count > maxMetrics {
            metrics.removeFirst(metrics.count - maxMetrics)
        }
    }
}

struct PerformanceMetric: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let duration: TimeInterval
    let timestamp: Date
    
    var formattedDuration: String {
        if duration < 0.001 {
            return String(format: "%.1f µs", duration * 1_000_000)
        } else if duration < 1.0 {
            return String(format: "%.1f ms", duration * 1000)
        } else {
            return String(format: "%.2f s", duration)
        }
    }
}

// MARK: - Crash Reporter

/// Simple crash & error reporter. Logs unhandled signals and stores crash reports locally.
/// In production, you'd forward these to a service like Sentry or Bugsnag.
final class CrashReporter: Sendable {
    static let shared = CrashReporter()
    
    private let directory: URL
    private let maxReports = 50
    private let logger = os.Logger(subsystem: "com.jarvis.planner", category: "CrashReporter")
    
    private init() {
        let docs = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        directory = docs.appendingPathComponent("JarvisCrashReports", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    
    /// Register signal handlers for common crash signals.
    func activate() {
        NSSetUncaughtExceptionHandler { exception in
            let report = CrashReport(
                type: .uncaughtException,
                name: exception.name.rawValue,
                reason: exception.reason ?? "Unknown",
                stackTrace: exception.callStackSymbols,
                timestamp: Date()
            )
            CrashReporter.shared.save(report)
        }
        
        // Register for common crash signals
        for sig: Int32 in [SIGABRT, SIGBUS, SIGFPE, SIGILL, SIGSEGV] {
            signal(sig) { sigNum in
                let report = CrashReport(
                    type: .signal,
                    name: "Signal \(sigNum)",
                    reason: CrashReporter.signalName(sigNum),
                    stackTrace: Thread.callStackSymbols,
                    timestamp: Date()
                )
                CrashReporter.shared.save(report)
                // Re-raise to get default crash behavior
                signal(sigNum, SIG_DFL)
                raise(sigNum)
            }
        }
        
        logger.info("CrashReporter activated")
    }
    
    /// Record an error manually (non-fatal).
    func recordError(_ error: Error, context: String = "", file: String = #file, line: Int = #line) {
        let report = CrashReport(
            type: .nonFatal,
            name: "\(type(of: error))",
            reason: "\(error.localizedDescription) [context: \(context)] at \(file):\(line)",
            stackTrace: Thread.callStackSymbols,
            timestamp: Date()
        )
        save(report)
        logger.error("Non-fatal error: \(error.localizedDescription) at \(file):\(line)")
    }
    
    /// Get all stored crash reports.
    func loadReports() -> [CrashReport] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey]) else {
            return []
        }
        return files
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
            .prefix(maxReports)
            .compactMap { url -> CrashReport? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(CrashReport.self, from: data)
            }
    }
    
    /// Clear all crash reports.
    func clearReports() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
        logger.info("Crash reports cleared")
    }
    
    /// Check if there are pending crash reports from a previous session.
    var hasPendingReports: Bool {
        let count = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil))?.count ?? 0
        return count > 0
    }
    
    // MARK: - Private
    
    private func save(_ report: CrashReport) {
        let filename = "\(ISO8601DateFormatter().string(from: report.timestamp))-\(report.type.rawValue).json"
            .replacingOccurrences(of: ":", with: "-")
        let url = directory.appendingPathComponent(filename)
        
        if let data = try? JSONEncoder().encode(report) {
            try? data.write(to: url, options: .atomic)
        }
        
        // Trim old reports
        trimReports()
    }
    
    private func trimReports() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .sorted(by: { $0.lastPathComponent > $1.lastPathComponent }) else { return }
        
        if files.count > maxReports {
            for file in files.dropFirst(maxReports) {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
    
    private static func signalName(_ signal: Int32) -> String {
        switch signal {
        case SIGABRT: return "SIGABRT (Abort)"
        case SIGBUS: return "SIGBUS (Bus Error)"
        case SIGFPE: return "SIGFPE (Floating Point Exception)"
        case SIGILL: return "SIGILL (Illegal Instruction)"
        case SIGSEGV: return "SIGSEGV (Segmentation Fault)"
        default: return "Signal \(signal)"
        }
    }
}

// MARK: - Crash Report Model

struct CrashReport: Codable, Identifiable, Sendable {
    var id: String { "\(timestamp.timeIntervalSince1970)-\(name)" }
    let type: CrashType
    let name: String
    let reason: String
    let stackTrace: [String]
    let timestamp: Date
    
    enum CrashType: String, Codable, Sendable {
        case uncaughtException
        case signal
        case nonFatal
    }
    
    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: timestamp)
    }
}

// MARK: - App Launch Tracker

/// Tracks app launch times and session metrics.
@MainActor
final class AppLaunchTracker: ObservableObject {
    static let shared = AppLaunchTracker()
    
    @Published private(set) var coldLaunchTime: TimeInterval?
    @Published private(set) var sessionCount: Int = 0
    
    private let launchStart = CFAbsoluteTimeGetCurrent()
    private let defaults = UserDefaults.standard
    private let sessionCountKey = "jarvis_session_count"
    private let lastLaunchKey = "jarvis_last_launch"
    
    private init() {
        sessionCount = defaults.integer(forKey: sessionCountKey)
    }
    
    /// Call once when the first meaningful view appears.
    func recordLaunchComplete() {
        guard coldLaunchTime == nil else { return }
        coldLaunchTime = CFAbsoluteTimeGetCurrent() - launchStart
        sessionCount += 1
        defaults.set(sessionCount, forKey: sessionCountKey)
        defaults.set(Date().timeIntervalSince1970, forKey: lastLaunchKey)
        
        let tracker = PerformanceTracker.shared
        let metric = PerformanceMetric(name: "cold_launch", duration: coldLaunchTime!, timestamp: Date())
        tracker.record(metric)
    }
}
