import SwiftUI

// MARK: - Completed Tab View (iPhone)
// Extracted from StructuredMainView to reduce God View size.
// Contains: completed tab, stats card, completed task row, empty state.

struct CompletedTabView: View {
    let theme: JarvisTheme
    @ObservedObject var store: PlannerStore
    @Binding var editingTask: PlannerTask?
    let onToggleTask: (PlannerTask) -> Void
    let onDeleteTask: (PlannerTask) -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 8) {
                    let completedTasks = store.completedTasks
                    
                    if completedTasks.isEmpty {
                        emptyCompletedView
                    } else {
                        completedStatsCard(tasks: completedTasks)
                        
                        ForEach(completedTasks) { task in
                            completedTaskRow(task)
                                .transition(.taskRowTransition)
                        }
                    }
                }
                .animation(.spring(response: 0.45, dampingFraction: 0.75), value: store.completedTasks.map(\.id))
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .background(theme.background)
            .dropDestination(for: String.self) { items, _ in
                guard let taskID = items.first, let uuid = UUID(uuidString: taskID) else { return false }
                store.moveTask(taskID: uuid, to: .completed)
                return true
            } isTargeted: { _ in }
            .navigationTitle(L10n.completedTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                if !store.completedTasks.isEmpty {
                    ToolbarItem(placement: .automatic) {
                        Button(L10n.clearAction) {
                            store.removeCompleted()
                        }
                        .foregroundColor(JarvisTheme.accent)
                    }
                }
            }
        }
    }
    
    // MARK: - Stats Card
    
    private func completedStatsCard(tasks: [PlannerTask]) -> some View {
        let todayCompleted = tasks.filter { Calendar.current.isDateInToday($0.date) }.count
        let weekCompleted = tasks.filter {
            guard let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else { return false }
            return $0.date >= weekAgo
        }.count
        
        return VStack(spacing: 16) {
            HStack(spacing: 20) {
                statItem(value: "\(tasks.count)", label: L10n.total, color: JarvisTheme.accent)
                statItem(value: "\(todayCompleted)", label: L10n.tabToday, color: JarvisTheme.accentGreen)
                statItem(value: "\(weekCompleted)", label: L10n.thisWeek, color: JarvisTheme.accentBlue)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.cardBackground)
                .shadow(color: theme.cardShadow, radius: 4, y: 2)
        )
        .padding(.bottom, 8)
    }
    
    private func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Task Row
    
    private func completedTaskRow(_ task: PlannerTask) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(task.taskColor.opacity(0.3))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(task.taskColor)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                    .strikethrough()
                
                Text(task.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 12))
                    .foregroundColor(theme.textTertiary)
            }
            
            Spacer()
            
            Button(action: { restoreTask(task) }) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 16))
                    .foregroundColor(theme.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.restoreTask)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.cardBackground)
        )
        .dockMagnificationEffect()
        .onTapGesture { editingTask = task }
        .contextMenu {
            Button {
                editingTask = task
            } label: {
                Label(L10n.editTask, systemImage: "pencil")
            }
            
            Button {
                restoreTask(task)
            } label: {
                Label(L10n.markIncomplete, systemImage: "arrow.uturn.backward")
            }
            
            Divider()
            
            Button(role: .destructive) {
                onDeleteTask(task)
            } label: {
                Label(L10n.deleteTask, systemImage: "trash")
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyCompletedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(theme.textTertiary)
            Text(L10n.noCompleted)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.textPrimary)
            Text(L10n.completedAppearHere)
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
    
    // MARK: - Actions
    
    private func restoreTask(_ task: PlannerTask) {
        var updated = task
        updated.isCompleted = false
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            store.update(updated)
        }
    }
}
