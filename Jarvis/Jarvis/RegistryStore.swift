import Foundation
import SwiftUI
import Combine

// MARK: - Registry Store

/// Persistence service for Registry catalogs.
/// Follows PlannerStore pattern — JSON file in Application Support, debounced saves.
@MainActor
final class RegistryStore: ObservableObject {
    static let shared = RegistryStore()

    @Published var registries: [Registry] = []

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var saveTask: Task<Void, Never>?

    private init() {
        load()
    }

    // MARK: - CRUD

    func add(_ registry: Registry) {
        registries.append(registry)
        scheduleSave()
    }

    func update(_ registry: Registry) {
        guard let idx = registries.firstIndex(where: { $0.id == registry.id }) else { return }
        registries[idx] = registry
        registries[idx].modifiedAt = Date()
        scheduleSave()
    }

    func delete(_ registry: Registry) {
        registries.removeAll { $0.id == registry.id }
        scheduleSave()
    }

    func delete(at offsets: IndexSet) {
        registries.remove(atOffsets: offsets)
        scheduleSave()
    }

    // MARK: - Row Helpers

    func addRow(to registryId: UUID, row: RegistryRow) {
        guard let idx = registries.firstIndex(where: { $0.id == registryId }) else { return }
        registries[idx].rows.append(row)
        registries[idx].modifiedAt = Date()
        scheduleSave()
    }

    func updateRow(in registryId: UUID, row: RegistryRow) {
        guard let rIdx = registries.firstIndex(where: { $0.id == registryId }),
              let rowIdx = registries[rIdx].rows.firstIndex(where: { $0.id == row.id }) else { return }
        registries[rIdx].rows[rowIdx] = row
        registries[rIdx].modifiedAt = Date()
        scheduleSave()
    }

    func deleteRow(in registryId: UUID, rowId: UUID) {
        guard let rIdx = registries.firstIndex(where: { $0.id == registryId }) else { return }
        registries[rIdx].rows.removeAll { $0.id == rowId }
        registries[rIdx].modifiedAt = Date()
        scheduleSave()
    }

    // MARK: - Column Helpers

    func addColumn(to registryId: UUID, column: RegistryColumn) {
        guard let idx = registries.firstIndex(where: { $0.id == registryId }) else { return }
        registries[idx].columns.append(column)
        registries[idx].modifiedAt = Date()
        scheduleSave()
    }

    func deleteColumn(in registryId: UUID, columnId: UUID) {
        guard let rIdx = registries.firstIndex(where: { $0.id == registryId }) else { return }
        registries[rIdx].columns.removeAll { $0.id == columnId }
        // Remove column data from all rows
        let colKey = columnId.uuidString
        for rowIdx in registries[rIdx].rows.indices {
            registries[rIdx].rows[rowIdx].cells.removeValue(forKey: colKey)
        }
        registries[rIdx].modifiedAt = Date()
        scheduleSave()
    }

    // MARK: - Persistence

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Jarvis", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("registries.json")
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            registries = try decoder.decode([Registry].self, from: data)
            Logger.shared.info("[RegistryStore] Loaded \(registries.count) registries")
        } catch {
            Logger.shared.error("[RegistryStore] Load failed: \(error.localizedDescription)")
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            self?.persist()
        }
    }

    private func persist() {
        do {
            let data = try encoder.encode(registries)
            try data.write(to: fileURL, options: .atomic)
            Logger.shared.debug("[RegistryStore] Saved \(registries.count) registries")
        } catch {
            Logger.shared.error("[RegistryStore] Save failed: \(error.localizedDescription)")
        }
    }
}
