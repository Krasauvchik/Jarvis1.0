import Foundation
import SwiftData
import SwiftUI
import Combine

// MARK: - Data Persistence Controller
// Manages SwiftData ModelContainer and migration from UserDefaults → SwiftData.
// CloudKit sync happens automatically via SwiftData when configured.

@MainActor
final class DataPersistence: ObservableObject {
    static let shared = DataPersistence()
    
    let container: ModelContainer
    let context: ModelContext
    
    @Published private(set) var isMigrated: Bool
    
    private static let migrationKey = "jarvis_swiftdata_migrated_v1"
    
    init() {
        let schema = Schema([
            TaskEntity.self,
            CategoryEntity.self,
            TagEntity.self,
            ProjectEntity.self,
            MealEntity.self,
            SleepEntity.self,
            ActivityEntity.self,
            WaterEntity.self
        ])
        
        // Try CloudKit first, then local-only, then in-memory as last resort
        if let c = Self.makeContainer(schema: schema, cloudKit: .automatic, inMemory: false) {
            container = c
        } else if let c = Self.makeContainer(schema: schema, cloudKit: .none, inMemory: false) {
            Logger.shared.error("DataPersistence: CloudKit unavailable, using local-only store.")
            container = c
        } else {
            // Corrupted store on disk — delete and retry, then fall back to in-memory
            Self.deleteStoreFiles(named: "JarvisStore")
            if let c = Self.makeContainer(schema: schema, cloudKit: .none, inMemory: false) {
                Logger.shared.error("DataPersistence: Deleted corrupted store, recreated local-only.")
                container = c
            } else if let c = Self.makeContainer(schema: schema, cloudKit: .none, inMemory: true) {
                Logger.shared.error("DataPersistence: Using in-memory store as last resort.")
                container = c
            } else {
                // Absolute last resort — minimal in-memory container
                container = try! ModelContainer(for: schema, configurations: [
                    ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
                ])
                Logger.shared.error("DataPersistence: Emergency in-memory container created.")
            }
        }
        
        context = ModelContext(container)
        context.autosaveEnabled = true
        isMigrated = UserDefaults.standard.bool(forKey: Self.migrationKey)
    }
    
    // MARK: - Container Factory
    
    private static func makeContainer(schema: Schema, cloudKit: ModelConfiguration.CloudKitDatabase, inMemory: Bool) -> ModelContainer? {
        let config = ModelConfiguration(
            "JarvisStore",
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: cloudKit
        )
        return try? ModelContainer(for: schema, configurations: [config])
    }
    
    /// Remove corrupted SQLite files from the default SwiftData location.
    private static func deleteStoreFiles(named name: String) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let storeDir = appSupport.appendingPathComponent("default.store")
        let suffixes = ["", "-wal", "-shm"]
        for suffix in suffixes {
            let file = storeDir.appendingPathExtension(suffix)
            try? FileManager.default.removeItem(at: file)
        }
        // Also try the named store
        for suffix in suffixes {
            let file = appSupport.appendingPathComponent("\(name).store\(suffix)")
            try? FileManager.default.removeItem(at: file)
        }
        Logger.shared.info("DataPersistence: Deleted store files for '\(name)'")
    }
    
    // MARK: - Migration from UserDefaults
    
    /// Migrates existing data from UserDefaults/iCloud KV store → SwiftData.
    /// Called once on first launch after upgrade.
    func migrateFromUserDefaultsIfNeeded(store: PlannerStore) {
        guard !isMigrated else { return }
        
        Logger.shared.info("Starting one-time migration from UserDefaults → SwiftData")
        
        // Migrate tasks
        for task in store.tasks {
            let entity = TaskEntity(from: task)
            context.insert(entity)
        }
        
        // Migrate categories
        for category in store.categories {
            let entity = CategoryEntity(from: category)
            context.insert(entity)
        }
        
        // Migrate tags
        for tag in store.tags {
            let entity = TagEntity(from: tag)
            context.insert(entity)
        }
        
        // Migrate projects
        for project in store.projects {
            let entity = ProjectEntity(from: project)
            context.insert(entity)
        }
        
        // Migrate wellness data from UserDefaults/CloudSync
        let decoder = JSONDecoder()
        if let snapshot = CloudSync.shared.loadWellness() {
            for meal in snapshot.meals { context.insert(MealEntity(from: meal)) }
            for entry in snapshot.sleep { context.insert(SleepEntity(from: entry)) }
            for activity in snapshot.activities { context.insert(ActivityEntity(from: activity)) }
            if let water = snapshot.waterEntries {
                for entry in water { context.insert(WaterEntity(from: entry)) }
            }
        } else if let data = UserDefaults.standard.data(forKey: Config.Storage.wellnessKey),
                  let snapshot = try? decoder.decode(WellnessSnapshot.self, from: data) {
            for meal in snapshot.meals { context.insert(MealEntity(from: meal)) }
            for entry in snapshot.sleep { context.insert(SleepEntity(from: entry)) }
            for activity in snapshot.activities { context.insert(ActivityEntity(from: activity)) }
            if let water = snapshot.waterEntries {
                for entry in water { context.insert(WaterEntity(from: entry)) }
            }
        }
        
        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: Self.migrationKey)
            isMigrated = true
            Logger.shared.info("Migration complete: \(store.tasks.count) tasks, \(store.categories.count) categories, \(store.tags.count) tags, \(store.projects.count) projects")
        } catch {
            Logger.shared.error("Migration save failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Task CRUD
    
    func loadTasks() -> [PlannerTask] {
        let descriptor = FetchDescriptor<TaskEntity>(sortBy: [SortDescriptor(\.date)])
        do {
            let entities = try context.fetch(descriptor)
            return entities.map { $0.toStruct() }
        } catch {
            Logger.shared.error("Failed to fetch tasks: \(error.localizedDescription)")
            return []
        }
    }
    
    func saveTask(_ task: PlannerTask) {
        let predicate = #Predicate<TaskEntity> { entity in
            entity.taskID == task.id
        }
        var descriptor = FetchDescriptor<TaskEntity>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        do {
            if let existing = try context.fetch(descriptor).first {
                existing.update(from: task)
            } else {
                context.insert(TaskEntity(from: task))
            }
            try context.save()
        } catch {
            Logger.shared.error("Failed to save task: \(error.localizedDescription)")
        }
    }
    
    func saveTasks(_ tasks: [PlannerTask]) {
        do {
            // O(1) lookup: fetch ALL existing entities once, build dictionary
            let existing = try context.fetch(FetchDescriptor<TaskEntity>())
            let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.taskID, $0) })
            
            let incomingIDs = Set(tasks.map(\.id))
            
            for task in tasks {
                if let entity = existingByID[task.id] {
                    entity.update(from: task)
                } else {
                    context.insert(TaskEntity(from: task))
                }
            }
            
            // Remove entities that no longer exist in the task list
            for entity in existing where !incomingIDs.contains(entity.taskID) {
                context.delete(entity)
            }
            
            try context.save()
        } catch {
            Logger.shared.error("Failed to batch save tasks: \(error.localizedDescription)")
        }
    }
    
    func deleteTask(id: UUID) {
        let predicate = #Predicate<TaskEntity> { entity in
            entity.taskID == id
        }
        do {
            try context.delete(model: TaskEntity.self, where: predicate)
            try context.save()
        } catch {
            Logger.shared.error("Failed to delete task: \(error.localizedDescription)")
        }
    }
    
    func deleteAllTasks() {
        do {
            try context.delete(model: TaskEntity.self)
            try context.save()
        } catch {
            Logger.shared.error("Failed to delete all tasks: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Category CRUD
    
    func loadCategories() -> [TaskCategory] {
        let descriptor = FetchDescriptor<CategoryEntity>(sortBy: [SortDescriptor(\.sortOrder)])
        do {
            return try context.fetch(descriptor).map { $0.toStruct() }
        } catch {
            Logger.shared.error("Failed to fetch categories: \(error.localizedDescription)")
            return []
        }
    }
    
    func saveCategory(_ category: TaskCategory) {
        let predicate = #Predicate<CategoryEntity> { entity in
            entity.categoryID == category.id
        }
        var descriptor = FetchDescriptor<CategoryEntity>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        do {
            if let existing = try context.fetch(descriptor).first {
                existing.update(from: category)
            } else {
                context.insert(CategoryEntity(from: category))
            }
            try context.save()
        } catch {
            Logger.shared.error("Failed to save category: \(error.localizedDescription)")
        }
    }
    
    func deleteCategory(id: UUID) {
        let predicate = #Predicate<CategoryEntity> { entity in
            entity.categoryID == id
        }
        do {
            try context.delete(model: CategoryEntity.self, where: predicate)
            try context.save()
        } catch {
            Logger.shared.error("Failed to delete category: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Tag CRUD
    
    func loadTags() -> [TaskTag] {
        let descriptor = FetchDescriptor<TagEntity>()
        do {
            return try context.fetch(descriptor).map { $0.toStruct() }
        } catch {
            Logger.shared.error("Failed to fetch tags: \(error.localizedDescription)")
            return []
        }
    }
    
    func saveTag(_ tag: TaskTag) {
        let predicate = #Predicate<TagEntity> { entity in
            entity.tagID == tag.id
        }
        var descriptor = FetchDescriptor<TagEntity>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        do {
            if let existing = try context.fetch(descriptor).first {
                existing.update(from: tag)
            } else {
                context.insert(TagEntity(from: tag))
            }
            try context.save()
        } catch {
            Logger.shared.error("Failed to save tag: \(error.localizedDescription)")
        }
    }
    
    func deleteTag(id: UUID) {
        let predicate = #Predicate<TagEntity> { entity in
            entity.tagID == id
        }
        do {
            try context.delete(model: TagEntity.self, where: predicate)
            try context.save()
        } catch {
            Logger.shared.error("Failed to delete tag: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Project CRUD
    
    func loadProjects() -> [Project] {
        let descriptor = FetchDescriptor<ProjectEntity>(sortBy: [SortDescriptor(\.createdAt)])
        do {
            return try context.fetch(descriptor).map { $0.toStruct() }
        } catch {
            Logger.shared.error("Failed to fetch projects: \(error.localizedDescription)")
            return []
        }
    }
    
    func saveProject(_ project: Project) {
        let predicate = #Predicate<ProjectEntity> { entity in
            entity.projectID == project.id
        }
        var descriptor = FetchDescriptor<ProjectEntity>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        do {
            if let existing = try context.fetch(descriptor).first {
                existing.update(from: project)
            } else {
                context.insert(ProjectEntity(from: project))
            }
            try context.save()
        } catch {
            Logger.shared.error("Failed to save project: \(error.localizedDescription)")
        }
    }
    
    func deleteProject(id: UUID) {
        let predicate = #Predicate<ProjectEntity> { entity in
            entity.projectID == id
        }
        do {
            try context.delete(model: ProjectEntity.self, where: predicate)
            try context.save()
        } catch {
            Logger.shared.error("Failed to delete project: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Batch Save Operations (O(1) fetch + dictionary lookup instead of N individual fetches)
    
    /// Batch-save all categories in a single transaction.
    /// Pre-fetches all existing entities into a dictionary for O(1) lookup.
    func saveCategories(_ categories: [TaskCategory]) {
        do {
            let existing = try context.fetch(FetchDescriptor<CategoryEntity>())
            let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.categoryID, $0) })
            
            for category in categories {
                if let entity = existingByID[category.id] {
                    entity.update(from: category)
                } else {
                    context.insert(CategoryEntity(from: category))
                }
            }
            try context.save()
        } catch {
            Logger.shared.error("Failed to batch-save categories: \(error.localizedDescription)")
        }
    }
    
    /// Batch-save all tags in a single transaction.
    func saveTags(_ tags: [TaskTag]) {
        do {
            let existing = try context.fetch(FetchDescriptor<TagEntity>())
            let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.tagID, $0) })
            
            for tag in tags {
                if let entity = existingByID[tag.id] {
                    entity.update(from: tag)
                } else {
                    context.insert(TagEntity(from: tag))
                }
            }
            try context.save()
        } catch {
            Logger.shared.error("Failed to batch-save tags: \(error.localizedDescription)")
        }
    }
    
    /// Batch-save all projects in a single transaction.
    func saveProjects(_ projects: [Project]) {
        do {
            let existing = try context.fetch(FetchDescriptor<ProjectEntity>())
            let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.projectID, $0) })
            
            for project in projects {
                if let entity = existingByID[project.id] {
                    entity.update(from: project)
                } else {
                    context.insert(ProjectEntity(from: project))
                }
            }
            try context.save()
        } catch {
            Logger.shared.error("Failed to batch-save projects: \(error.localizedDescription)")
        }
    }
}
