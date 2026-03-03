#if !os(watchOS)
import SwiftUI

// MARK: - Inline AI Command Bar
/// Встроенная панель AI + голоса. Не overlay — располагается в layout-стеке.
/// Визуально отделена тонким divider сверху, но в том же дизайн-языке.

struct AICommandBar: View {
    @ObservedObject var aiManager: AIManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dependencies) private var dependencies

    @State private var inputText = ""
    @State private var isExpanded = false
    @State private var isVoiceActive = false
    @State private var showFullChat = false
    @State private var quickResponse: String?
    @State private var isProcessing = false
    @State private var pulseAnimation = false

    @StateObject private var speech = SpeechRecognizer()

    private var theme: JarvisTheme {
        JarvisTheme.current(for: colorScheme)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Response toast above bar
            if let response = quickResponse {
                aiResponseToast(response)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Quick chips when expanded
            if isExpanded {
                quickActionChips
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Divider — визуальное отделение от контента
            Rectangle()
                .fill(theme.divider)
                .frame(height: 0.5)

            // Main bar
            mainBar
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(theme.sidebarBackground)
        }
        .sheet(isPresented: $showFullChat) {
            NavigationStack {
                AIChatView(aiManager: aiManager)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Готово") { showFullChat = false }
                        }
                    }
            }
        }
        .onChange(of: speech.transcript) { _, newValue in
            if !speech.isRecording && !newValue.isEmpty {
                inputText = newValue
                if isVoiceActive {
                    sendQuickCommand()
                    isVoiceActive = false
                }
            }
        }
    }

    // MARK: - Main Bar

    private var mainBar: some View {
        HStack(spacing: 8) {
            // Mic button
            micButton

            if isExpanded {
                // Text input
                TextField("Спросите Jarvis...", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isVoiceActive ? JarvisTheme.accentOrange : theme.divider, lineWidth: isVoiceActive ? 1.5 : 0.5)
                    )
                    .onSubmit { sendQuickCommand() }
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .leading)))

                // Send
                Button(action: sendQuickCommand) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                         ? theme.textTertiary : JarvisTheme.accent)
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                .transition(.scale(scale: 0.5).combined(with: .opacity))

                // Collapse
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded = false
                        inputText = ""
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.textTertiary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(theme.cardBackground))
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.5).combined(with: .opacity))
            } else {
                // Collapsed: tappable prompt pill
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded = true
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(JarvisTheme.accentPurple)
                        Text("Спросите Jarvis...")
                            .font(.system(size: 13))
                            .foregroundColor(theme.textTertiary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                // Full chat button
                Button(action: { showFullChat = true }) {
                    Image(systemName: "bubble.left.and.text.bubble.right")
                        .font(.system(size: 15))
                        .foregroundColor(JarvisTheme.accentPurple)
                        .frame(width: 32, height: 32)
                        .background(JarvisTheme.accentPurple.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Открыть полный AI-чат")
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
    }

    // MARK: - Mic Button

    private var micButton: some View {
        Button(action: toggleVoice) {
            ZStack {
                if speech.isRecording {
                    Circle()
                        .stroke(JarvisTheme.accentOrange.opacity(0.4), lineWidth: 2)
                        .frame(width: 42, height: 42)
                        .scaleEffect(pulseAnimation ? 1.25 : 1.0)
                        .opacity(pulseAnimation ? 0 : 0.5)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false), value: pulseAnimation)
                }

                Circle()
                    .fill(
                        speech.isRecording
                        ? LinearGradient(colors: [JarvisTheme.accentOrange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [JarvisTheme.accent, JarvisTheme.accentPurple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 36, height: 36)
                    .shadow(color: (speech.isRecording ? JarvisTheme.accentOrange : JarvisTheme.accent).opacity(0.3), radius: 4, y: 2)

                Image(systemName: speech.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: 42, height: 42)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(speech.isRecording ? "Остановить запись" : "Голосовая команда")
        .onAppear { pulseAnimation = true }
        .disabled(isProcessing)
    }

    // MARK: - Quick Action Chips

    private var quickActionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip(icon: "doc.text.magnifyingglass", text: "Выдержка", color: JarvisTheme.accentPurple) {
                    inputText = "Подготовь выдержку по ближайшей встрече"
                    sendQuickCommand()
                }
                chip(icon: "magnifyingglass", text: "Поиск", color: JarvisTheme.accentBlue) {
                    inputText = "Найди всё по теме "
                }
                chip(icon: "text.badge.star", text: "Обзор дня", color: JarvisTheme.accentGreen) {
                    inputText = "Покажи обзор моего дня"
                    sendQuickCommand()
                }
                chip(icon: "figure.run", text: "Коуч", color: JarvisTheme.accentOrange) {
                    inputText = "Дай план тренировки на сегодня"
                    sendQuickCommand()
                }
                chip(icon: "paperplane.fill", text: "Делегировать", color: JarvisTheme.accentTeal) {
                    inputText = "Поставь задачу пользователю "
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func chip(icon: String, text: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(text)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Response Toast

    private func aiResponseToast(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 16))
                .foregroundColor(JarvisTheme.accentPurple)

            VStack(alignment: .leading, spacing: 3) {
                Text(text)
                    .font(.system(size: 13))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(4)
                    .textSelection(.enabled)

                Button("Открыть в чате") {
                    showFullChat = true
                    quickResponse = nil
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(JarvisTheme.accent)
            }

            Spacer()

            Button(action: {
                withAnimation(.easeOut(duration: 0.2)) { quickResponse = nil }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.textTertiary)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(theme.cardBackground))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.cardBackground)
                .shadow(color: theme.cardShadow.opacity(0.5), radius: 6, y: 2)
        )
    }

    // MARK: - Actions

    private func toggleVoice() {
        if speech.isRecording {
            speech.stop()
            if !speech.transcript.isEmpty {
                inputText = speech.transcript
            }
        } else {
            isVoiceActive = true
            if !isExpanded {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded = true
                }
            }
            speech.start()
        }
    }

    private func sendQuickCommand() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isProcessing else { return }

        inputText = ""
        isProcessing = true

        Task { @MainActor in
            let tasks = dependencies.plannerStore.tasks
            let response = await aiManager.sendCommand(text, tasks: tasks)
            isProcessing = false

            if let actions = response.actions, !actions.isEmpty {
                let executor = VoiceCommandExecutor()
                _ = executor.execute(actions: actions)
            }

            let preview = String(response.response.prefix(300))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                quickResponse = preview
                isExpanded = false
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                withAnimation(.easeOut(duration: 0.3)) {
                    if quickResponse == preview { quickResponse = nil }
                }
            }
        }
    }
}

// MARK: - AI Welcome Header

struct AIWelcomeHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var userProfile = UserProfile.shared

    private var theme: JarvisTheme {
        JarvisTheme.current(for: colorScheme)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 6 { return "Доброй ночи" }
        if hour < 12 { return "Доброе утро" }
        if hour < 18 { return "Добрый день" }
        return "Добрый вечер"
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [JarvisTheme.accent, JarvisTheme.accentPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("\(greeting), \(userProfile.name.isEmpty ? "пользователь" : userProfile.name)!")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(theme.textPrimary)

                Text("Говорите или пишите — Jarvis поможет")
                    .font(.system(size: 12))
                    .foregroundColor(theme.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            JarvisTheme.accentPurple.opacity(0.06),
                            JarvisTheme.accent.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }
}
#endif
