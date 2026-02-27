import SwiftUI

struct CalendarView: View {
    @State private var events: [CalendarEventItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isAuthorized = false
    @State private var checkingAuth = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                JarvisTheme.background.ignoresSafeArea()
                
                if checkingAuth {
                    ProgressView("Проверка...")
                } else if !isAuthorized {
                    authPromptView
                } else if let err = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text(err)
                            .multilineTextAlignment(.center)
                            .foregroundColor(JarvisTheme.textSecondary)
                            .padding()
                        Button("Повторить") { Task { await loadEvents() } }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding()
                } else if events.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(JarvisTheme.textSecondary)
                        Text("Нет событий")
                            .font(.headline)
                            .foregroundColor(JarvisTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(events) { event in
                                CalendarEventRow(event: event)
                                    .jarvisSectionCard()
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Календарь")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    if isAuthorized && errorMessage == nil {
                        Button {
                            Task { await loadEvents() }
                        } label: {
                            if isLoading {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .disabled(isLoading)
                    }
                }
            }
            .task {
                await checkAuth()
            }
            .refreshable {
                await checkAuth()
                if isAuthorized { await loadEvents() }
            }
        }
    }
    
    private var authPromptView: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(JarvisTheme.accent)
            Text("Подключите Google")
                .font(.title2.weight(.semibold))
                .foregroundColor(JarvisTheme.textPrimary)
            Text("Войдите в аккаунт Google, чтобы видеть события календаря и почту.")
                .multilineTextAlignment(.center)
                .foregroundColor(JarvisTheme.textSecondary)
                .padding(.horizontal)
            Button {
                AuthService.shared.openAuthInBrowser()
            } label: {
                Label("Войти через Google", systemImage: "link")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 32)
        }
    }
    
    private func checkAuth() async {
        checkingAuth = true
        defer { checkingAuth = false }
        do {
            isAuthorized = try await AuthService.shared.checkAuth()
            errorMessage = nil
        } catch {
            isAuthorized = false
            errorMessage = "Ошибка: \(error.localizedDescription)"
        }
    }
    
    private func loadEvents() async {
        guard isAuthorized else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let dtos = try await CalendarService.shared.fetchEventsAsDTO()
            events = dtos.map { CalendarEventItem(id: $0.id, title: $0.title, notes: $0.notes, startDate: $0.startDate) }
        } catch {
            errorMessage = error.localizedDescription
            events = []
        }
    }
}

struct CalendarEventItem: Identifiable {
    let id: String
    let title: String
    let notes: String?
    let startDate: Date
}

struct CalendarEventRow: View {
    let event: CalendarEventItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(event.title)
                .font(.headline)
                .foregroundColor(JarvisTheme.textPrimary)
            Text(event.startDate.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline)
                .foregroundColor(JarvisTheme.textSecondary)
            if let notes = event.notes, !notes.isEmpty {
                let preview = String(notes.prefix(80))
                    .replacingOccurrences(of: "<br>", with: " ")
                    .replacingOccurrences(of: "<br/>", with: " ")
                Text(preview)
                    .font(.caption)
                    .foregroundColor(JarvisTheme.textSecondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}
