#if !os(watchOS)
import SwiftUI

// MARK: - Chat message model

struct AIChatMessage: Identifiable {
    let id = UUID()
    let role: String // "user" | "assistant"
    let content: String
    let date: Date = Date()
}

// MARK: - AI Chat View (окно нейросети)

struct AIChatView: View {
    @ObservedObject var aiManager: AIManager
    @Environment(\.dependencies) private var dependencies
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var messages: [AIChatMessage] = []
    @State private var inputText = ""
    @State private var isWaitingReply = false
    @State private var errorMessage: String?
    
    #if os(iOS)
    @StateObject private var speech = SpeechRecognizer()
    #endif
    
    private var theme: JarvisTheme {
        JarvisTheme.current(for: colorScheme)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if let err = errorMessage {
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
                            HStack(alignment: .top, spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.9)
                                Text("Думаю...")
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
        .navigationTitle("Нейросеть")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 56))
                .foregroundStyle(theme.textTertiary)
            Text("Напишите или скажите что-нибудь")
                .font(.subheadline)
                .foregroundColor(theme.textSecondary)
            Text("AI может управлять задачами, календарём, почтой. Попробуйте: «Какие дела на сегодня?» или «Создай задачу купить молоко на завтра»")
                .font(.caption)
                .foregroundColor(theme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
    
    private func chatBubble(_ msg: AIChatMessage) -> some View {
        let isUser = msg.role == "user"
        return HStack(alignment: .top, spacing: 8) {
            if isUser { Spacer(minLength: 40) }
            if !isUser {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 20))
                    .foregroundColor(JarvisTheme.accentPurple)
            }
            Text(msg.content)
                .font(.subheadline)
                .foregroundColor(isUser ? .white : theme.textPrimary)
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
    }
    
    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            #if os(iOS)
            Button(action: toggleVoice) {
                Image(systemName: speech.isRecording ? "stop.circle.fill" : "mic.fill")
                    .font(.system(size: 22))
                    .foregroundColor(speech.isRecording ? JarvisTheme.accentOrange : theme.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(isWaitingReply)
            #endif
            
            TextField("Сообщение...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: JarvisTheme.Dimensions.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: JarvisTheme.Dimensions.cornerRadius)
                        .stroke(theme.divider, lineWidth: 1)
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
        #if os(iOS)
        .onChange(of: speech.transcript) { _, newValue in
            if !speech.isRecording && !newValue.isEmpty {
                inputText = newValue
            }
        }
        #endif
    }
    
    #if os(iOS)
    private func toggleVoice() {
        if speech.isRecording {
            speech.stop()
            if !speech.transcript.isEmpty {
                inputText = speech.transcript
            }
        } else {
            speech.start()
        }
    }
    #endif
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isWaitingReply else { return }
        
        errorMessage = nil
        inputText = ""
        
        let userMsg = AIChatMessage(role: "user", content: text)
        messages.append(userMsg)
        isWaitingReply = true
        
        Task { @MainActor in
            // Use unified command that can handle tasks, calendar, mail AND chat
            let tasks = dependencies.plannerStore.tasks
            let response = await aiManager.sendCommand(text, tasks: tasks)
            isWaitingReply = false
            
            var replyText = response.response
            
            // Process executed actions and append info
            if let actions = response.actions, !actions.isEmpty {
                let actionDescriptions = actions.compactMap { action -> String? in
                    switch action.type {
                    case "create_task":
                        return "✅ Создана задача: \(action.params["title"] ?? "")"
                    case "complete_task":
                        return "✅ Выполнено: \(action.params["title"] ?? "")"
                    case "show_calendar":
                        return "📅 Открываю календарь"
                    case "show_mail":
                        return "📧 Открываю почту"
                    case "send_email":
                        return "📧 Отправлено письмо → \(action.params["to"] ?? "")"
                    default:
                        return nil
                    }
                }
                if !actionDescriptions.isEmpty {
                    replyText += "\n\n" + actionDescriptions.joined(separator: "\n")
                }
            }
            
            messages.append(AIChatMessage(role: "assistant", content: replyText))
        }
    }
}
#endif
