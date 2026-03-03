#if !os(watchOS)
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
                contentView
            }
            .navigationTitle(L10n.calendarTitle)
            .toolbar { toolbarContent }
            .task { await checkAuth() }
            .refreshable {
                await checkAuth()
                if isAuthorized { await loadEvents() }
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if checkingAuth {
            ProgressView(L10n.checking)
        } else if !isAuthorized {
            authPromptView
        } else if let err = errorMessage {
            errorView(err)
        } else if events.isEmpty {
            emptyView
        } else {
            eventsList
        }
    }
    
    private var eventsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    CalendarEventRow(event: event)
                        .jarvisSectionCard()
                        .animateOnAppear(delay: Double(index) * 0.05)
                        .transition(.cardAppear)
                }
            }
            .padding()
        }
    }
    
    private func errorView(_ err: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text(err)
                .multilineTextAlignment(.center)
                .foregroundStyle(JarvisTheme.textSecondary)
                .padding()
            Button(L10n.retry) { Task { await loadEvents() } }
                .buttonStyle(PrimaryButtonStyle())
                .bounceOnTap()
        }
        .padding()
        .animateOnAppear(delay: 0.1)
    }
    
    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(JarvisTheme.textSecondary)
            Text(L10n.noEvents)
                .font(.headline)
                .foregroundStyle(JarvisTheme.textSecondary)
        }
        .animateOnAppear(delay: 0.1)
    }
    
    private var authPromptView: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(JarvisTheme.accent)
            Text(L10n.connectGoogle)
                .font(.title2.weight(.semibold))
                .foregroundStyle(JarvisTheme.textPrimary)
            Text(L10n.connectGoogleCalDesc)
                .multilineTextAlignment(.center)
                .foregroundStyle(JarvisTheme.textSecondary)
                .padding(.horizontal)
            Button {
                AuthService.shared.openAuthInBrowser()
            } label: {
                Label(L10n.signInGoogle, systemImage: "link")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(PrimaryButtonStyle())
            .bounceOnTap()
            .padding(.horizontal, 32)
        }
        .animateOnAppear(delay: 0)
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            if isAuthorized && errorMessage == nil {
                Button { Task { await loadEvents() } } label: {
                    if isLoading { ProgressView() }
                    else { Image(systemName: "arrow.clockwise") }
                }
                .bounceOnTap()
                .disabled(isLoading)
            }
        }
    }
    
    private func checkAuth() async {
        checkingAuth = true
        defer { checkingAuth = false }
        do {
            isAuthorized = try await AuthService.shared.checkAuth()
            if isAuthorized { await loadEvents() }
        } catch {
            isAuthorized = false
            errorMessage = "\(L10n.errorGeneric): \(error.localizedDescription)"
        }
    }
    
    private func loadEvents() async {
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
                .foregroundStyle(JarvisTheme.textPrimary)
            Text(event.startDate.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(JarvisTheme.textSecondary)
            if let notes = event.notes, !notes.isEmpty {
                Text(String(notes.prefix(80)).replacingOccurrences(of: "<br>", with: " ").replacingOccurrences(of: "<br/>", with: " "))
                    .font(.caption)
                    .foregroundStyle(JarvisTheme.textSecondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}
#endif
