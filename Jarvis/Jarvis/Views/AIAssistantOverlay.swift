#if !os(watchOS)
import SwiftUI
import AVFoundation
import Combine

// MARK: - TTS Service

@MainActor
final class JarvisTTS: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = JarvisTTS()
    private let synth = AVSpeechSynthesizer()
    @Published var isSpeaking = false

    override init() {
        super.init()
        synth.delegate = self
    }

    func speak(_ text: String) {
        synth.stopSpeaking(at: .immediate)

        // Strip emojis and formatting for cleaner speech
        let cleaned = text
            .replacingOccurrences(of: "\\p{So}|\\p{Sk}", with: "", options: .regularExpression)
            .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return }

        let utterance = AVSpeechUtterance(string: cleaned)
        // Auto-detect language
        let isRussian = cleaned.range(of: "\\p{Cyrillic}", options: .regularExpression) != nil
        utterance.voice = AVSpeechSynthesisVoice(language: isRussian ? "ru-RU" : "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.05
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        isSpeaking = true
        synth.speak(utterance)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
}

// MARK: - Chat Message Model

struct AssistantMessage: Identifiable, Equatable {
    let id = UUID()
    let role: AssistantRole
    let text: String
    let timestamp: Date = Date()

    enum AssistantRole: Equatable {
        case user
        case assistant
    }

    static func == (lhs: AssistantMessage, rhs: AssistantMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - AI Assistant Overlay (Full-screen overlay with floating pill)

struct AIAssistantOverlay: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.colorScheme) private var colorScheme

    @State private var isOpen = false
    @State private var messages: [AssistantMessage] = []
    @State private var inputText = ""
    @State private var isTyping = false
    @State private var showSuggestions = true
    @State private var voiceEnabled = true
    @State private var isRecordingVoice = false
    @StateObject private var tts = JarvisTTS.shared
    @StateObject private var speech = SpeechRecognizer()
    private let executor = VoiceCommandExecutor()

    private var theme: JarvisTheme {
        JarvisTheme.current(for: colorScheme)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Dimmed backdrop when open
            if isOpen {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                    .transition(.opacity)
            }

            // Chat panel
            if isOpen {
                chatPanel
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
            }

            // Floating pill button (hidden when panel is open)
            if !isOpen {
                floatingPill
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isOpen)
    }

    private func close() {
        tts.stop()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isOpen = false
        }
    }

    private func open() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            isOpen = true
        }
    }

    // MARK: - Floating Pill Button

    private var floatingPill: some View {
        Button(action: open) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .medium))
                Text("Jarvis")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.35, green: 0.35, blue: 0.38),
                                Color(red: 0.25, green: 0.25, blue: 0.28)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
            )
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20)
        .padding(.bottom, 90)
    }

    // MARK: - Chat Panel

    private var chatPanel: some View {
        VStack(spacing: 0) {
            // Header
            panelHeader

            Divider().opacity(0.3)

            // Messages
            messageList

            // Suggestion chips (only when empty or after assistant reply)
            if showSuggestions && !isTyping {
                suggestionChips
            }

            Divider().opacity(0.3)

            // Input bar
            inputBar
        }
        .frame(maxWidth: 420)
        #if os(iOS)
        .frame(maxHeight: UIScreen.main.bounds.height * 0.7)
        #else
        .frame(maxHeight: 520)
        #endif
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 30, y: 10)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    // MARK: - Panel Header

    private var panelHeader: some View {
        HStack(spacing: 12) {
            // Jarvis avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.55, green: 0.5, blue: 0.9), Color(red: 0.4, green: 0.35, blue: 0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)

                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Jarvis")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.textPrimary)

                Text(isTyping ? L10n.thinking : L10n.jarvisHelperSubtitle)
                    .font(.system(size: 12))
                    .foregroundColor(isTyping ? JarvisTheme.accentPurple : theme.textTertiary)
            }

            Spacer()

            // Voice toggle
            Button(action: {
                if tts.isSpeaking { tts.stop() }
                voiceEnabled.toggle()
            }) {
                Image(systemName: voiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(voiceEnabled ? JarvisTheme.accentPurple : theme.textTertiary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(theme.chipBackground))
            }
            .buttonStyle(.plain)

            // Close
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.textTertiary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(theme.chipBackground))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if messages.isEmpty {
                        emptyState
                    } else {
                        ForEach(messages) { msg in
                            messageBubble(msg)
                                .id(msg.id)
                        }

                        if isTyping {
                            typingIndicator
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: isTyping) { _, typing in
                if typing {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("typing", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 30)

            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundStyle(
                    LinearGradient(
                        colors: [JarvisTheme.accentPurple, JarvisTheme.accentBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(L10n.askJarvis)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(theme.textPrimary)

            Text(L10n.voiceControlSubtitle)
                .font(.system(size: 13))
                .foregroundColor(theme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Spacer().frame(height: 10)
        }
    }

    // MARK: - Message Bubble

    private func messageBubble(_ msg: AssistantMessage) -> some View {
        let isUser = msg.role == .user

        return HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 48) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(msg.text)
                    .font(.system(size: 15))
                    .foregroundColor(isUser ? .white : theme.textPrimary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isUser
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [Color(red: 0.55, green: 0.5, blue: 0.9), Color(red: 0.4, green: 0.35, blue: 0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                          )
                        : AnyShapeStyle(theme.cardBackground)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Text(msg.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundColor(theme.textMuted)
                    .padding(.horizontal, 6)
            }

            if !isUser { Spacer(minLength: 48) }
        }
    }

    // MARK: - Typing Indicator

    private var typingIndicator: some View {
        HStack(spacing: 0) {
            HStack(spacing: 5) {
                ForEach(0..<3) { i in
                    TypingDot(delay: Double(i) * 0.15)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Spacer()
        }
        .id("typing")
    }

    // MARK: - Suggestion Chips

    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                suggestionChip("☀️", L10n.chipWeather) {
                    sendMessage(L10n.promptWeather)
                }
                suggestionChip("💰", L10n.chipRates) {
                    sendMessage(L10n.promptRates)
                }
                suggestionChip("📋", L10n.chipDayOverview) {
                    sendMessage(L10n.promptDayOverview)
                }
                suggestionChip("🧠", L10n.chipCoach) {
                    sendMessage(L10n.promptCoach)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func suggestionChip(_ emoji: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(emoji)
                    .font(.system(size: 13))
                Text(label)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
            }
            .foregroundColor(theme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(theme.chipBackground)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            // Mic button for voice input
            Button(action: toggleVoiceInput) {
                Image(systemName: speech.isRecording ? "mic.fill" : "mic")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(speech.isRecording ? .red : theme.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(speech.isRecording ? Color.red.opacity(0.15) : theme.chipBackground)
                    )
                    .scaleEffect(speech.isRecording ? 1.15 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: speech.isRecording)
            }
            .buttonStyle(.plain)

            TextField(L10n.askJarvis, text: $inputText, axis: .vertical)
                .font(.system(size: 15))
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(theme.cardBackground)
                )
                .onSubmit { sendMessage() }

            // Send button
            Button(action: { sendMessage() }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(
                        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? AnyShapeStyle(theme.textMuted)
                        : AnyShapeStyle(
                            LinearGradient(
                                colors: [Color(red: 0.55, green: 0.5, blue: 0.9), Color(red: 0.4, green: 0.35, blue: 0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                          )
                    )
            }
            .buttonStyle(.plain)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTyping)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .onChange(of: speech.isRecording) { _, recording in
            if !recording && !speech.transcript.isEmpty {
                // Voice stopped — send the transcript
                let voiceText = speech.transcript
                speech.transcript = ""
                sendMessage(voiceText)
            }
        }
    }

    private func toggleVoiceInput() {
        if speech.isRecording {
            speech.stop()
        } else {
            tts.stop()
            inputText = ""
            speech.start()
        }
    }

    // MARK: - Gemini Conversation History

    /// Builds Gemini-compatible message history from our messages
    private var geminiHistory: [(role: String, content: String)] {
        messages.map { msg in
            (role: msg.role == .user ? "user" : "assistant", content: msg.text)
        }
    }

    /// System prompt for Gemini conversation with action support
    private var conversationalSystemPrompt: String {
        let tasks = dependencies.plannerStore.tasks
        let tasksList = tasks.prefix(15).map { "- \($0.title)\($0.isCompleted ? " ✓" : "")" }.joined(separator: "\n")
        let eventKit = EventKitService.shared
        let calendarCtx = eventKit.calendarContextForLLM()

        return """
        Ты — Jarvis, дружелюбный и умный AI-ассистент внутри приложения-планировщика.
        Ты можешь отвечать на ЛЮБЫЕ вопросы — погода, советы, юмор, знания, переводы, математика.

        Текущая дата и время: \(AIManager.currentDateTimeForLLM())
        Часовой пояс: \(AIManager.currentTimezoneOffset())

        Задачи пользователя:
        \(tasksList.isEmpty ? "Нет задач" : tasksList)

        \(calendarCtx)

        ВАЖНО — СОЗДАНИЕ ЗАДАЧ И СОБЫТИЙ:
        Когда пользователь просит создать/выполнить/удалить/перенести задачу или событие,
        ты ДОЛЖЕН вернуть СТРОГО JSON (без markdown, без ```) в таком формате:
        {"response": "✅ Задача создана", "actions": [{"type": "create_task", "params": {"title": "Название", "date": "ISO8601+TZ", "priority": "medium"}}]}

        Допустимые типы действий:
        - create_task: params: title, date (ISO8601+TZ), notes, priority (low/medium/high), duration, is_inbox (true если без даты)
        - complete_task: params: title (название задачи для поиска)
        - delete_task: params: title
        - reschedule_task: params: title, new_date (ISO8601+TZ)
        - create_event: params: title, date (ISO8601+TZ), end_date (ISO8601+TZ), location, notes
        - delete_event: params: title
        - reschedule_event: params: title, new_date (ISO8601+TZ), new_end_date (ISO8601+TZ)

        Все даты — СТРОГО в формате ISO8601 с часовым поясом пользователя: "\(AIManager.currentTimezoneOffset())".
        Пример: "\(AIManager.exampleDateForLLM())"
        Когда пользователь говорит "на 10", "в 14:00" — это ЛОКАЛЬНОЕ время.

        КРИТИЧНО: для действий отвечай СТРОГО JSON без пояснений вокруг.
        Для обычных вопросов (не связанных с задачами/событиями) — отвечай обычным текстом.
        Отвечай кратко, живо, по-человечески. По умолчанию на русском.
        """
    }

    // MARK: - JSON Extraction for Actions

    /// Extracts AICommandResponse JSON from LLM text
    private func extractJSON(from text: String) -> AICommandResponse? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let data = cleaned.data(using: .utf8),
           let response = try? JSONDecoder().decode(AICommandResponse.self, from: data) {
            return response
        }

        guard let firstBrace = cleaned.firstIndex(of: "{"),
              let lastBrace = cleaned.lastIndex(of: "}") else { return nil }

        let jsonStr = String(cleaned[firstBrace...lastBrace])
        guard let data = jsonStr.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AICommandResponse.self, from: data)
    }

    // MARK: - Send Message (Direct Gemini + Action Execution)

    private func sendMessage(_ override: String? = nil) {
        let text = (override ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isTyping else { return }

        inputText = ""
        showSuggestions = false
        messages.append(AssistantMessage(role: .user, text: text))
        isTyping = true

        Task { @MainActor in
            let gemini = GeminiService.shared
            let chatMessages = geminiHistory

            var response: String
            if gemini.isConfigured {
                if let result = await gemini.chat(
                    messages: chatMessages,
                    systemPrompt: conversationalSystemPrompt,
                    temperature: 0.3,
                    maxTokens: 1500
                ) {
                    response = result
                } else {
                    response = "Не удалось получить ответ от Gemini. Проверьте подключение к интернету."
                }
            } else {
                response = "Gemini не настроен. Добавьте API ключ в настройках."
            }

            // Try to parse JSON actions from Gemini response
            if let parsed = extractJSON(from: response) {
                response = parsed.response
                if let actions = parsed.actions, !actions.isEmpty {
                    let log = await executor.execute(actions: actions)
                    let logText = log.filter { !$0.isEmpty }.joined(separator: "\n")
                    if !logText.isEmpty {
                        response += "\n\n" + logText
                    }
                }
            }

            isTyping = false
            messages.append(AssistantMessage(role: .assistant, text: response))

            if voiceEnabled {
                tts.speak(response)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation { showSuggestions = true }
            }
        }
    }
}

// MARK: - Typing Dot Animation

private struct TypingDot: View {
    let delay: Double
    @State private var animated = false

    var body: some View {
        Circle()
            .fill(Color.gray.opacity(0.5))
            .frame(width: 8, height: 8)
            .offset(y: animated ? -4 : 4)
            .animation(
                .easeInOut(duration: 0.5)
                .repeatForever(autoreverses: true)
                .delay(delay),
                value: animated
            )
            .onAppear { animated = true }
    }
}
#endif
