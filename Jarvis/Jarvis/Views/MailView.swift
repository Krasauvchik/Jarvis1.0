#if !os(watchOS)
import SwiftUI

struct MailView: View {
    @State private var messages: [MailService.MessageDTO] = []
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
            .navigationTitle(L10n.mailTitle)
            .toolbar { toolbarContent }
            .task { await checkAuth() }
            .refreshable {
                await checkAuth()
                if isAuthorized { await loadMail() }
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
        } else if messages.isEmpty {
            emptyView
        } else {
            messagesList
        }
    }
    
    private var messagesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(messages.enumerated()), id: \.element.id) { index, msg in
                    MailMessageRow(message: msg)
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
            Button(L10n.retry) { Task { await loadMail() } }
                .buttonStyle(PrimaryButtonStyle())
                .bounceOnTap()
        }
        .padding()
        .animateOnAppear(delay: 0.1)
    }
    
    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "envelope.badge")
                .font(.system(size: 48))
                .foregroundStyle(JarvisTheme.textSecondary)
            Text(L10n.noMails)
                .font(.headline)
                .foregroundStyle(JarvisTheme.textSecondary)
        }
        .animateOnAppear(delay: 0.1)
    }
    
    private var authPromptView: some View {
        VStack(spacing: 24) {
            Image(systemName: "envelope.badge")
                .font(.system(size: 64))
                .foregroundStyle(JarvisTheme.accent)
            Text(L10n.connectGoogle)
                .font(.title2.weight(.semibold))
                .foregroundStyle(JarvisTheme.textPrimary)
            Text(L10n.connectGoogleMailDesc)
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
                Button { Task { await loadMail() } } label: {
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
            if isAuthorized { await loadMail() }
        } catch {
            isAuthorized = false
            errorMessage = "Ошибка: \(error.localizedDescription)"
        }
    }
    
    private func loadMail() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            messages = try await MailService.shared.fetchMessages(maxResults: 15)
        } catch MailError.notAuthorized(let msg) {
            errorMessage = msg ?? L10n.authRequired
            messages = []
        } catch {
            errorMessage = error.localizedDescription
            messages = []
        }
    }
}

struct MailMessageRow: View {
    let message: MailService.MessageDTO
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message.subject.isEmpty ? L10n.noSubject : message.subject)
                .font(.headline)
                .foregroundStyle(JarvisTheme.textPrimary)
                .lineLimit(1)
            Text(message.from)
                .font(.subheadline)
                .foregroundStyle(JarvisTheme.textSecondary)
                .lineLimit(1)
            Text(message.snippet)
                .font(.caption)
                .foregroundStyle(JarvisTheme.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}
#endif
