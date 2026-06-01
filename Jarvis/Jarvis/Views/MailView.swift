#if !os(watchOS)
import SwiftUI

struct MailView: View {
    @State private var messages: [MailService.MessageDTO] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isAuthorized = false
    @State private var checkingAuth = true
    @State private var showCompose = false
    @State private var replyToMessage: MailService.MessageDTO?
    
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
            .sheet(isPresented: $showCompose) {
                MailComposeSheet { await loadMail() }
            }
            .sheet(item: $replyToMessage) { msg in
                MailReplySheet(message: msg) { await loadMail() }
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
        List {
            ForEach(Array(messages.enumerated()), id: \.element.id) { index, msg in
                NavigationLink(destination: MailDetailView(messageId: msg.id, snippet: msg)) {
                    MailMessageRow(message: msg, onReply: { replyToMessage = msg })
                }
                .listRowBackground(JarvisTheme.cardBackground)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task { await deleteMessage(msg) }
                    } label: {
                        Label(L10n.delete, systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
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
                HStack(spacing: 12) {
                    Button { showCompose = true } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .bounceOnTap()
                    
                    Button { Task { await loadMail() } } label: {
                        if isLoading { ProgressView() }
                        else { Image(systemName: "arrow.clockwise") }
                    }
                    .bounceOnTap()
                    .disabled(isLoading)
                }
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
            errorMessage = "\(L10n.errorGeneric): \(error.localizedDescription)"
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
    
    private func deleteMessage(_ msg: MailService.MessageDTO) async {
        do {
            try await MailService.shared.deleteMessage(id: msg.id)
            messages.removeAll { $0.id == msg.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct MailMessageRow: View {
    let message: MailService.MessageDTO
    let onReply: () -> Void
    
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
            HStack {
                Spacer()
                Button(action: onReply) {
                    Label(L10n.reply, systemImage: "arrowshape.turn.up.left.fill")
                        .font(.caption)
                        .foregroundStyle(JarvisTheme.accent)
                }
                .buttonStyle(.plain)
                .bounceOnTap()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

// MARK: - Mail Compose Sheet

struct MailComposeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var to = ""
    @State private var subject = ""
    @State private var messageBody = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    let onSent: () async -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.mailTo, text: $to)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        #endif
                    TextField(L10n.mailSubject, text: $subject)
                    TextEditor(text: $messageBody)
                        .frame(minHeight: 150)
                }
                
                if let err = errorMessage {
                    Section {
                        Text(err)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(L10n.mailCompose)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSending {
                        ProgressView()
                    } else {
                        Button(L10n.mailSend) { Task { await send() } }
                            .disabled(to.isEmpty || subject.isEmpty)
                    }
                }
            }
        }
    }
    
    private func send() async {
        isSending = true
        errorMessage = nil
        do {
            _ = try await MailService.shared.sendMessage(to: to, subject: subject, body: messageBody)
            await onSent()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSending = false
    }
}

// MARK: - Mail Reply Sheet

struct MailReplySheet: View {
    let message: MailService.MessageDTO
    var initialBody: String? = nil
    let onSent: () async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var replyBody = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(L10n.mailOriginal)) {
                    Text(message.from)
                        .font(.subheadline)
                        .foregroundStyle(JarvisTheme.textSecondary)
                    Text(message.subject)
                        .font(.subheadline.weight(.semibold))
                    Text(message.snippet)
                        .font(.caption)
                        .foregroundStyle(JarvisTheme.textSecondary)
                        .lineLimit(4)
                }
                
                Section(header: Text(L10n.reply)) {
                    TextEditor(text: $replyBody)
                        .frame(minHeight: 150)
                }
                
                if let err = errorMessage {
                    Section {
                        Text(err)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(L10n.mailReplyTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSending {
                        ProgressView()
                    } else {
                        Button(L10n.mailSend) { Task { await reply() } }
                            .disabled(replyBody.isEmpty)
                    }
                }
            }
            .onAppear {
                if let initial = initialBody, replyBody.isEmpty {
                    replyBody = initial
                }
            }
        }
    }
    
    private func reply() async {
        isSending = true
        errorMessage = nil
        do {
            _ = try await MailService.shared.replyToMessage(messageId: message.id, body: replyBody)
            await onSent()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSending = false
    }
}

// MARK: - Mail Detail View

struct MailDetailView: View {
    let messageId: String
    let snippet: MailService.MessageDTO
    
    @State private var detail: MailService.MessageDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showReply = false
    @State private var showDeleteConfirm = false
    @State private var summaryText: String?
    @State private var isSummarizing = false
    @State private var aiReplyDraft: String?
    @State private var isGeneratingReply = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            JarvisTheme.background.ignoresSafeArea()
            
            if isLoading {
                ProgressView(L10n.loading)
            } else if let err = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundStyle(.orange)
                    Text(err)
                        .font(.subheadline)
                        .foregroundStyle(JarvisTheme.textSecondary)
                        .multilineTextAlignment(.center)
                    Button(L10n.retry) { Task { await loadDetail() } }
                        .buttonStyle(PrimaryButtonStyle())
                        .bounceOnTap()
                }
                .padding()
            } else if let msg = detail {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text(msg.subject.isEmpty ? L10n.noSubject : msg.subject)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(JarvisTheme.textPrimary)
                            
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .foregroundStyle(JarvisTheme.accent)
                                Text(msg.from)
                                    .font(.subheadline)
                                    .foregroundStyle(JarvisTheme.textSecondary)
                            }
                            
                            if let to = msg.to, !to.isEmpty {
                                HStack {
                                    Text(L10n.mailTo + ":")
                                        .font(.caption)
                                        .foregroundStyle(JarvisTheme.textTertiary)
                                    Text(to)
                                        .font(.caption)
                                        .foregroundStyle(JarvisTheme.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                            
                            Text(msg.date)
                                .font(.caption)
                                .foregroundStyle(JarvisTheme.textTertiary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(JarvisTheme.cardBackground)
                        .cornerRadius(12)
                        
                        // Body
                        Text(msg.body.isEmpty ? msg.snippet : msg.body)
                            .font(.body)
                            .foregroundStyle(JarvisTheme.textPrimary)
                            .textSelection(.enabled)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(JarvisTheme.cardBackground)
                            .cornerRadius(12)
                        
                        // AI Summary
                        if let summary = summaryText {
                            VStack(alignment: .leading, spacing: 8) {
                                Label(L10n.aiSummary, systemImage: "sparkles")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(JarvisTheme.accent)
                                Text(summary)
                                    .font(.subheadline)
                                    .foregroundStyle(JarvisTheme.textPrimary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(JarvisTheme.accent.opacity(0.08))
                            .cornerRadius(12)
                        }
                        
                        // AI Action Buttons
                        HStack(spacing: 12) {
                            Button {
                                Task { await summarizeMessage(msg) }
                            } label: {
                                Label(isSummarizing ? L10n.generating : L10n.aiSummarize, systemImage: "sparkles")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.bordered)
                            .tint(.purple)
                            .bounceOnTap()
                            .disabled(isSummarizing)
                            
                            Button {
                                Task { await generateReply(msg) }
                            } label: {
                                Label(isGeneratingReply ? L10n.generating : L10n.aiReply, systemImage: "wand.and.stars")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.bordered)
                            .tint(.indigo)
                            .bounceOnTap()
                            .disabled(isGeneratingReply)
                        }
                        
                        // Actions
                        HStack(spacing: 16) {
                            Button {
                                showReply = true
                            } label: {
                                Label(L10n.reply, systemImage: "arrowshape.turn.up.left.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .bounceOnTap()
                            
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Label(L10n.delete, systemImage: "trash")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            .bounceOnTap()
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                }
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await loadDetail(); await markRead() }
        .sheet(isPresented: $showReply) {
            MailReplySheet(message: snippet, initialBody: aiReplyDraft) {
                await loadDetail()
            }
        }
        .alert(L10n.delete, isPresented: $showDeleteConfirm) {
            Button(L10n.cancel, role: .cancel) { }
            Button(L10n.delete, role: .destructive) {
                Task {
                    do {
                        try await MailService.shared.deleteMessage(id: messageId)
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        } message: {
            Text(L10n.mailDeleteConfirm)
        }
    }
    
    private func loadDetail() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            detail = try await MailService.shared.fetchMessage(id: messageId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func markRead() async {
        try? await MailService.shared.markAsRead(id: messageId)
    }
    
    private func summarizeMessage(_ msg: MailService.MessageDetail) async {
        isSummarizing = true
        defer { isSummarizing = false }
        do {
            let text = msg.body.isEmpty ? msg.snippet : msg.body
            let result = try await MailService.shared.summarize(text: text, maxSentences: 3)
            summaryText = result
        } catch {
            summaryText = error.localizedDescription
        }
    }
    
    private func generateReply(_ msg: MailService.MessageDetail) async {
        isGeneratingReply = true
        defer { isGeneratingReply = false }
        do {
            let text = msg.body.isEmpty ? msg.snippet : msg.body
            let result = try await MailService.shared.generateReplyDraft(
                originalText: text,
                instruction: "",
                tone: "professional"
            )
            aiReplyDraft = result
            showReply = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
#endif
