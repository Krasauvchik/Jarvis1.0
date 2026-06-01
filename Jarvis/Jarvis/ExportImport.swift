import Foundation
import SwiftUI
#if os(iOS)
import UniformTypeIdentifiers
#endif

// MARK: - Export Data Model

struct JarvisExportData: Codable {
    let exportDate: Date
    let version: Int
    let tasks: [PlannerTask]
    let categories: [TaskCategory]
    let tags: [TaskTag]
    let dayBounds: DayBounds?

    static let currentVersion = 1
}

// MARK: - Export / Import

@MainActor
enum ExportImport {
    
    // MARK: - JSON Export
    
    static func createExportURL(store: PlannerStore) -> URL? {
        let data = JarvisExportData(
            exportDate: Date(),
            version: JarvisExportData.currentVersion,
            tasks: store.tasks,
            categories: store.categories,
            tags: store.tags,
            dayBounds: store.dayBounds
        )
        guard let encoded = try? JSONEncoder().encode(data) else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        let name = "jarvis_backup_\(formatter.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try encoded.write(to: url)
            return url
        } catch {
            return nil
        }
    }
    
    // MARK: - CSV Export
    
    static func createCSVExportURL(store: PlannerStore) -> URL? {
        let tasks = store.tasks
        let categories = store.categories
        let tags = store.tags
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        
        // Build category & tag lookup maps
        let catMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        let tagMap = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0.name) })
        
        // CSV header
        let header = [
            "ID", "Title", "Notes", "Date", "Duration (min)", "Is All Day",
            "Is Completed", "Completed At", "Priority", "Category", "Tags",
            "Is Inbox", "Project ID", "Parent Task ID", "Source",
            "Spent Minutes", "Created At", "Modified At",
            "Reminders Count", "Attachments Count", "Comments Count"
        ].joined(separator: ",")
        
        var lines = [header]
        
        for task in tasks {
            let row = [
                task.id.uuidString,
                csvEscape(task.title),
                csvEscape(task.notes),
                isoFormatter.string(from: task.date),
                "\(task.durationMinutes)",
                task.isAllDay ? "true" : "false",
                task.isCompleted ? "true" : "false",
                task.completedAt.map { isoFormatter.string(from: $0) } ?? "",
                task.priority.rawValue,
                task.categoryId.flatMap { catMap[$0] } ?? "",
                csvEscape(task.tagIds.compactMap { tagMap[$0] }.joined(separator: "; ")),
                task.isInbox ? "true" : "false",
                task.projectId?.uuidString ?? "",
                task.parentTaskId?.uuidString ?? "",
                task.source.rawValue,
                "\(task.spentMinutes)",
                isoFormatter.string(from: task.createdAt),
                isoFormatter.string(from: task.modifiedAt),
                "\(task.reminders.count)",
                "\(task.attachments.count)",
                "\(task.comments.count)"
            ].joined(separator: ",")
            lines.append(row)
        }
        
        let csvString = lines.joined(separator: "\n")
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        let name = "jarvis_tasks_\(formatter.string(from: Date())).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        
        do {
            // UTF-8 BOM for Excel compatibility
            var bom = Data([0xEF, 0xBB, 0xBF])
            bom.append(csvString.data(using: .utf8) ?? Data())
            try bom.write(to: url)
            return url
        } catch {
            return nil
        }
    }
    
    /// Escapes a string for CSV: wraps in double quotes if it contains comma, newline, or quote.
    private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
    
    // MARK: - JSON Import

    static func importFromURL(_ url: URL, store: PlannerStore, merge: Bool) -> String? {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(JarvisExportData.self, from: data) else {
            return L10n.exportReadError
        }
        if merge {
            store.mergeImported(tasks: decoded.tasks, categories: decoded.categories, tags: decoded.tags)
            return L10n.exportMergeComplete
        } else {
            store.replaceWithImported(
                tasks: decoded.tasks,
                categories: decoded.categories,
                tags: decoded.tags,
                dayBounds: decoded.dayBounds
            )
            return "\(L10n.exportImported): \(decoded.tasks.count)"
        }
    }
}
