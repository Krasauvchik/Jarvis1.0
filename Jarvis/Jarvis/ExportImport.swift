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
