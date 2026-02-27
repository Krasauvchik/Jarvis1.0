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
                        Button("Повторить") { Task { await loadMail() } }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding()
                } else if messages.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "envelope.badge")
                            .font(.system(size: 48))
                            .foregroundColor(JarvisTheme.textSecondary)
                        Text("Нет писем")
                            .font(.headline)
                            .foregroundColor(JarvisTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages, id: \.id) { msg in
                                MailMessageRow(message: msg)
                                    .jarvisSectionCard()
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Почта")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    if isAuthorized && errorMessage == nil {
                        Button {
                            Task { await loadMail() }
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
                if isAuthorized { await loadMail() }
            }
        }
    }
    
    private var authPromptView: some View {
        VStack(spacing: 24) {
            Image(systemName: "envelope.badge")
                .font(.system(size: 64))
                .foregroundColor(JarvisTheme.accent)
            Text("Подключите Google")
                .font(.title2.weight(.semibold))
                .foregroundColor(JarvisTheme.textPrimary)
            Text("Войдите в аккаунт Google, чтобы видеть письма.")
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
    
    private func loadMail() async {
        guard isAuthorized else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            messages = try await MailService.shared.fetchMessages(maxResults: 15)
        } catch MailError.notAuthorized(let msg) {
            errorMessage = msg ?? "Требуется авторизация"
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
            Text(message.subject.isEmpty ? "(Без темы)" : message.subject)
                .font(.headline)
                .foregroundColor(JarvisTheme.textPrimary)
                .lineLimit(1)
            Text(message.from)
                .font(.subheadline)
                .foregroundColor(JarvisTheme.textSecondary)
                .lineLimit(1)
            Text(message.snippet)
                .font(.caption)
                .foregroundColor(JarvisTheme.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}
