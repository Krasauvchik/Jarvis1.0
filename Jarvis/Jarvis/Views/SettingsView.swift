#if !os(watchOS)
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: PlannerStore
    @ObservedObject var aiManager: AIManager
    @StateObject private var cloudSync = CloudSync.shared
    
    @State private var showDeleteCompletedConfirm = false
    @State private var showDeleteAllConfirm = false
    
    var body: some View {
        NavigationStack {
            List {
                aiSection
                    .animateOnAppear(delay: 0)
                syncSection
                    .animateOnAppear(delay: 0.05)
                tasksSection
                    .animateOnAppear(delay: 0.1)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.tasks.count)
            .navigationTitle("Настройки")
            .confirmationDialog("Удалить выполненные?", isPresented: $showDeleteCompletedConfirm, titleVisibility: .visible) {
                Button("Удалить", role: .destructive) {
                    NotificationManager.shared.cancelAll()
                    store.removeCompleted()
                }
                Button("Отмена", role: .cancel) { }
            } message: {
                Text("Будут удалены все задачи со статусом «выполнено».")
            }
            .confirmationDialog("Удалить все задачи?", isPresented: $showDeleteAllConfirm, titleVisibility: .visible) {
                Button("Удалить всё", role: .destructive) {
                    NotificationManager.shared.cancelAll()
                    store.removeAll()
                }
                Button("Отмена", role: .cancel) { }
            } message: {
                Text("Все задачи и напоминания будут удалены. Это действие нельзя отменить.")
            }
        }
    }
    
    private var aiSection: some View {
        Section {
            Picker("Модель ИИ", selection: $aiManager.selectedModel) {
                ForEach(AIModel.allCases) { model in
                    Text(model.displayName).tag(model)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text("Нейросеть")
        } footer: {
            Text("Используется для разбора задач, советов и анализа.")
        }
    }
    
    private var syncSection: some View {
        Section {
            HStack {
                Label("iCloud синхронизация", systemImage: "icloud")
                Spacer()
                if cloudSync.isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if let date = cloudSync.lastSyncDate {
                    Text(date.formatted(date: .omitted, time: .shortened))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Включено")
                        .foregroundStyle(.secondary)
                }
            }
            if let err = cloudSync.syncError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Button("Синхронизировать сейчас") {
                cloudSync.forceSync()
            }
            .bounceOnTap()
            .disabled(cloudSync.isSyncing)
        } header: {
            Text("Синхронизация")
        } footer: {
            Text("Данные автоматически синхронизируются между вашими устройствами Apple через iCloud. При появлении сети синхронизация запускается автоматически.")
        }
    }
    
    private var tasksSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteCompletedConfirm = true
            } label: {
                Label("Удалить выполненные задачи", systemImage: "checkmark.circle")
            }
            .bounceOnTap()
            .disabled(store.tasks.filter(\.isCompleted).isEmpty)
            
            Button(role: .destructive) {
                showDeleteAllConfirm = true
            } label: {
                Label("Удалить все задачи", systemImage: "trash")
            }
            .bounceOnTap()
            .disabled(store.tasks.isEmpty)
        } header: {
            Text("Задачи")
        }
    }
}
#endif
