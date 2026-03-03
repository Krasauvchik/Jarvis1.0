#if !os(watchOS)
import SwiftUI

// MARK: - Chat message model

struct AIChatMessage: Identifiable {
    let id = UUID()
    let role: String // "user" | "assistant" | "system"
    let content: String
    let date: Date = Date()
    var actions: [AIAction]? = nil
}

// MARK: - AI Chat View (окно нейросети с голосовым управлением)

struct AIChatView: View {
    @ObservedObject var aiManager: AIManager
    @Environment(\.dependencies) private var dependencies
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var messages: [AIChatMessage] = []
    @State private var inputText = ""
    @State private var isWaitingReply = false
    @State private var errorMessage: String?
    @State private var showDigestSheet = false
    @State private var isVoiceMode = false
    
    @StateObject private var speech = SpeechRecognizer()
    @StateObject private var commandExecutor = VoiceCommandExecutor()
    @StateObject private var digestService = LLMDigestService()
    
    private var theme: JarvisTheme {
        JarvisTheme.current(for: colorScheme)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if let err = errorMessage {
                errorBanner(err)
            }
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if messages.isEmpty {
                            emptyState
                        } else {
                            ForEach(messages) { msg in
                                chatBubble(msg)
                                    .id(msg.id)
                            }
                        }
                        if isWaitingReply {
                            thinkingIndicator
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            .background(theme.background)
            
            inputBar
        }
        .background(theme.background)
        .navigationTitle("Jarvis AI")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { requestDigest() }) {
                    Image(systemName: "text.redaction")
                        .foregroundColor(digestService.isLoading ? theme.textTertiary : JarvisTheme.accentPurple)
                }
                .disabled(digestService.isLoading)
                .help("AI-выдержка по задачам, календарю и почте")
            }
        }
        .onChange(of: speech.transcript) { _, newValue in
            if !speech.isRecording && !newValue.isEmpty {
                // Голосовая команда завершена — отправляем автоматически
                inputText = newValue
                if isVoiceMode {
                    sendMessage()
                    isVoiceMode = false
                }
            }
        }
        .sheet(isPresented: $showDigestSheet) {
            digestSheet
        }
    }
    
    // MARK: - Error Banner
    
    private func errorBanner(_ err: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(JarvisTheme.accentOrange)
            Text(err)
                .font(.caption)
                .foregroundColor(theme.textSecondary)
            Spacer()
            Button("Скрыть") { errorMessage = nil }
                .font(.caption)
                .foregroundColor(JarvisTheme.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.cardBackground)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 56))
                .foregroundStyle(theme.textTertiary)
            Text("Голосовое управление Jarvis")
                .font(.headline)
                .foregroundColor(theme.textPrimary)
            Text("Управляйте задачами голосом или текстом. Попробуйте:")
                .font(.subheadline)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 8) {
                voiceHint("🗣 «Создай задачу купить молоко на завтра в 10:00»")
                voiceHint("✅ «Отметь задачу купить молоко как выполненную»")
                voiceHint("� «Подготовь выдержку по встрече Соевый соус»")
                voiceHint("🔍 «Найди всё по теме проект Alpha»")
                voiceHint("💪 «Поставь задачу — качать плечи в зале»")
                voiceHint("📤 «Поставь задачу ревью пользователю @nick»")
                voiceHint("📊 «Покажи выдержку по моему дню»")
                voiceHint("📧 «Покажи непрочитанные письма»")
            }
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
    
    private func voiceHint(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(theme.textTertiary)
    }
    
    // MARK: - Thinking Indicator
    
    private var thinkingIndicator: some View {
        HStack(alignment: .top, spacing: 8) {
            ProgressView()
                .scaleEffect(0.9)
            Text(speech.isRecording ? "Слушаю..." : "Думаю...")
                .font(.subheadline)
                .foregroundColor(theme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: JarvisTheme.Dimensions.cornerRadius))
        .padding(.leading, 40)
    }
    
    // MARK: - Chat Bubble with Actions
    
    private func chatBubble(_ msg: AIChatMessage) -> some View {
        let isUser = msg.role == "user"
        return VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                if isUser { Spacer(minLength: 40) }
                if !isUser {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 20))
                        .foregroundColor(JarvisTheme.accentPurple)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(msg.content)
                        .font(.subheadline)
                        .foregroundColor(isUser ? .white : theme.textPrimary)
                        .textSelection(.enabled)
                    
                    // Show action badges
                    if let actions = msg.actions, !actions.isEmpty {
                        ForEach(actions) { action in
                            actionBadge(action)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    isUser
                    ? JarvisTheme.accent
                    : theme.cardBackground
                )
                .clipShape(RoundedRectangle(cornerRadius: JarvisTheme.Dimensions.cornerRadius))
                if !isUser { Spacer(minLength: 40) }
            }
            
            // Timestamp
            Text(msg.date.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundColor(theme.textTertiary)
                .padding(.horizontal, isUser ? 4 : 36)
        }
    }
    
    private func actionBadge(_ action: AIAction) -> some View {
        let (icon, color) = actionIconAndColor(action.type)
        return HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(action.params["title"] ?? action.type)
                .font(.caption2)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .clipShape(Capsule())
    }
    
    private func actionIconAndColor(_ type: String) -> (String, Color) {
        switch type {
        case "create_task": return ("plus.circle.fill", JarvisTheme.accentGreen)
        case "complete_task": return ("checkmark.circle.fill", JarvisTheme.accentGreen)
        case "delete_task": return ("trash.fill", JarvisTheme.accentOrange)
        case "reschedule_task": return ("calendar.badge.clock", JarvisTheme.accentBlue)
        case "move_task": return ("folder.fill", JarvisTheme.accentPurple)
        case "create_event": return ("calendar.badge.plus", JarvisTheme.accentBlue)
        case "send_email": return ("envelope.fill", JarvisTheme.accent)
        case "show_calendar": return ("calendar", JarvisTheme.accentBlue)
        case "show_mail": return ("envelope.open.fill", JarvisTheme.accent)
        case "meeting_briefing": return ("doc.text.magnifyingglass", JarvisTheme.accentPurple)
        case "context_search": return ("magnifyingglass", JarvisTheme.accentBlue)
        case "coaching": return ("figure.run", JarvisTheme.accentGreen)
        case "delegate_task": return ("paperplane.fill", JarvisTheme.accentOrange)
        default: return ("sparkles", theme.textSecondary)
        }
    }
    
    // MARK: - Input Bar
    
    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            // Voice button
            Button(action: toggleVoice) {
                ZStack {
                    Circle()
                        .fill(speech.isRecording ? JarvisTheme.accentOrange.opacity(0.15) : Color.clear)
                        .frame(width: 40, height: 40)
                    Image(systemName: speech.isRecording ? "stop.circle.fill" : "mic.fill")
                        .font(.system(size: 22))
                        .foregroundColor(speech.isRecording ? JarvisTheme.accentOrange : theme.textSecondary)
                }
            }
            .buttonStyle(.plain)
            .disabled(isWaitingReply)
            .help(speech.isRecording ? "Остановить запись" : "Голосовая команда")
            
            TextField("Сообщение или голосовая команда...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: JarvisTheme.Dimensions.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: JarvisTheme.Dimensions.cornerRadius)
                        .stroke(speech.isRecording ? JarvisTheme.accentOrange : theme.divider, lineWidth: speech.isRecording ? 2 : 1)
                )
                .disabled(isWaitingReply)
                .onSubmit { sendMessage() }
            
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? theme.textTertiary : JarvisTheme.accent)
            }
            .buttonStyle(.plain)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isWaitingReply)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(theme.sidebarBackground)
    }
    
    // MARK: - Digest Sheet
    
    private var digestSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if digestService.isLoading {
                        HStack {
                            ProgressView()
                            Text("Собираю данные из всех источников...")
                                .font(.subheadline)
                                .foregroundColor(theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else if let digest = digestService.lastDigest {
                        // Summary
                        VStack(alignment: .leading, spacing: 8) {
                            Label("AI-выдержка", systemImage: "brain.head.profile")
                                .font(.headline)
                                .foregroundColor(JarvisTheme.accentPurple)
                            Text(digest.summary)
                                .font(.subheadline)
                                .foregroundColor(theme.textPrimary)
                                .textSelection(.enabled)
                        }
                        .padding()
                        .background(theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Calendar events
                        if !digest.calendarEvents.isEmpty {
                            digestSection(title: "📅 Календарь", items: digest.calendarEvents.map { "\($0.title) — \($0.time)" })
                        }
                        
                        // Mail
                        if !digest.mailHighlights.isEmpty {
                            digestSection(title: "📧 Почта", items: digest.mailHighlights.map { "\($0.from): \($0.subject)" })
                        }
                        
                        // Messengers
                        if !digest.messengerNotes.isEmpty {
                            digestSection(title: "💬 Мессенджеры", items: digest.messengerNotes.map { "[\($0.source)] \($0.summary)" })
                        }
                        
                        Text("Обновлено: \(digest.generatedAt.formatted(date: .omitted, time: .standard))")
                            .font(.caption)
                            .foregroundColor(theme.textTertiary)
                    } else {
                        Text("Нажмите «Обновить» для генерации выдержки")
                            .font(.subheadline)
                            .foregroundColor(theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    }
                }
                .padding()
            }
            .background(theme.background)
            .navigationTitle("AI Выдержка")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: { requestDigest() }) {
                        Label("Обновить", systemImage: "arrow.clockwise")
                    }
                    .disabled(digestService.isLoading)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Готово") { showDigestSheet = false }
                }
            }
        }
    }
    
    private func digestSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(theme.textPrimary)
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Text("• \(item)")
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Actions
    
    private func toggleVoice() {
        if speech.isRecording {
            speech.stop()
            if !speech.transcript.isEmpty {
                inputText = speech.transcript
            }
        } else {
            isVoiceMode = true
            speech.start()
        }
    }
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isWaitingReply else { return }
        
        errorMessage = nil
        inputText = ""
        
        // Check for digest request
        let lower = text.lowercased()
        if lower.contains("выдержк") || lower.contains("digest") || lower.contains("сводк") || lower.contains("обзор дня") {
            messages.append(AIChatMessage(role: "user", content: text))
            requestDigest()
            return
        }
        
        let userMsg = AIChatMessage(role: "user", content: text)
        messages.append(userMsg)
        isWaitingReply = true
        
        Task { @MainActor in
            let tasks = dependencies.plannerStore.tasks
            let response = await aiManager.sendCommand(text, tasks: tasks)
            isWaitingReply = false
            
            // Execute actions locally (create_task, complete_task, etc.)
            var replyText = response.response
            var executedActions: [AIAction] = []
            
            if let actions = response.actions, !actions.isEmpty {
                executedActions = actions
                let log = commandExecutor.execute(actions: actions)
                let logText = log.filter { !$0.isEmpty }.joined(separator: "\n")
                if !logText.isEmpty {
                    replyText += "\n\n" + logText
                }
            }
            
            // Add server-executed results (calendar/mail data)
            if let executed = response.executed {
                for exec in executed {
                    if let data = exec["data"]?.value as? [[String: Any]], let type = exec["type"]?.value as? String {
                        if type == "show_calendar" {
                            let items = data.prefix(5).compactMap { $0["title"] as? String }
                            if !items.isEmpty {
                                replyText += "\n\n📅 Ближайшие события:\n" + items.map { "• \($0)" }.joined(separator: "\n")
                            }
                        } else if type == "show_mail" {
                            let items = data.prefix(5).compactMap { dict -> String? in
                                guard let subj = dict["subject"] as? String, let from = dict["from"] as? String else { return nil }
                                return "\(from): \(subj)"
                            }
                            if !items.isEmpty {
                                replyText += "\n\n📧 Последние письма:\n" + items.map { "• \($0)" }.joined(separator: "\n")
                            }
                        }
                    }
                }
            }
            
            messages.append(AIChatMessage(
                role: "assistant",
                content: replyText,
                actions: executedActions.isEmpty ? nil : executedActions
            ))
        }
    }
    
    private func requestDigest() {
        showDigestSheet = true
        
        Task { @MainActor in
            let tasks = dependencies.plannerStore.tasks
            
            // Check which integrations user has enabled
            let sources = LLMDigestService.DigestSources(
                includeCalendar: UserDefaults.standard.bool(forKey: Config.Storage.skillCalendarKey),
                includeMail: UserDefaults.standard.bool(forKey: Config.Storage.skillMailKey),
                includeTelegram: UserDefaults.standard.bool(forKey: Config.Storage.skillTelegramKey),
                includeWhatsApp: UserDefaults.standard.bool(forKey: Config.Storage.skillWhatsAppKey)
            )
            
            if let digest = await digestService.generateDigest(tasks: tasks, sources: sources) {
                // Also add to chat as a message
                let shortSummary = String(digest.summary.prefix(500))
                messages.append(AIChatMessage(
                    role: "assistant",
                    content: "📊 AI-выдержка сгенерирована:\n\n\(shortSummary)\n\n(Полная версия — в листе выдержки)"
                ))
            }
        }
    }
}
#endif
