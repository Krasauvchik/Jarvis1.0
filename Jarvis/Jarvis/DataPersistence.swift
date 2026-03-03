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
        
        let config = ModelConfiguration(
            "JarvisStore",
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        
        do {
            container = try ModelContainer(for: schema, configurations: [config])
            context = ModelContext(container)
            context.autosaveEnabled = true
        } catch {
            // Fallback: in-memory only (no CloudKit)
            Logger.shared.error("Failed to create ModelContainer with CloudKit: \(error.localizedDescription). Falling back to local-only.")
            let fallbackConfig = ModelConfiguration(
                "JarvisStore",
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            do {
                container = try ModelContainer(for: schema, configurations: [fallbackConfig])
                context = ModelContext(container)
                context.autosaveEnabled = true
            } catch {
                fatalError("DataPersistence: cannot create ModelContainer: \(error)")
            }
        }
        
        isMigrated = UserDefaults.standard.bool(forKey: Self.migrationKey)
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
        for task in tasks {
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
            } catch {
                Logger.shared.error("Failed to upsert task \(task.id): \(error.localizedDescription)")
            }
        }
        
        do {
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
}
