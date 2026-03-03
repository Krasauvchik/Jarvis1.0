import SwiftUI
import Combine

// MARK: - Messenger Integration Settings View
/// UI для настройки Telegram и WhatsApp интеграций.
/// Позволяет: ввести API-ключи → авторизоваться → выбрать чаты для мониторинга.

struct MessengerSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    TelegramSetupSection()
                    WhatsAppSetupSection()
                }
                .padding()
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle(L10n.messengersTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.close) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Telegram Setup Section

struct TelegramSetupSection: View {
    @Environment(\.theme) private var theme
    @StateObject private var vm = TelegramSetupVM()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "paperplane.fill")
                    .font(.title2)
                    .foregroundColor(Color(red: 0.07, green: 0.72, blue: 0.34))
                Text("Telegram")
                    .font(.title3.bold())
                    .foregroundColor(theme.textPrimary)
                Spacer()
                statusBadge(vm.connectionState)
            }
            
            switch vm.setupPhase {
            case .notConfigured:
                telegramCredentialsForm
                
            case .configured:
                telegramAuthSection
                
            case .awaitingCode:
                telegramCodeEntry
                
            case .needs2FA:
                telegram2FAEntry
                
            case .authorized:
                telegramConnected
                
            case .chatSelection:
                telegramChatSelection
            }
            
            if let error = vm.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 4)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBackground))
        .task { await vm.checkStatus() }
    }
    
    // --- Sub-views ---
    
    private var telegramCredentialsForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.telegramAPIDesc)
                .font(.caption)
                .foregroundColor(theme.textSecondary)
            
            Link(L10n.telegramGetKeys, destination: URL(string: "https://my.telegram.org/apps")!)
                .font(.caption.bold())
            
            TextField("API ID", text: $vm.apiId)
                .textFieldStyle(.roundedBorder)
            #if os(iOS)
                .keyboardType(.numberPad)
            #endif
            
            TextField("API Hash", text: $vm.apiHash)
                .textFieldStyle(.roundedBorder)
            
            TextField(L10n.phoneNumber, text: $vm.phone)
                .textFieldStyle(.roundedBorder)
            #if os(iOS)
                .keyboardType(.phonePad)
            #endif
            
            Button(action: { Task { await vm.configure() } }) {
                HStack {
                    if vm.isLoading { ProgressView().scaleEffect(0.8) }
                    Text(L10n.connect)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.07, green: 0.72, blue: 0.34))
            .disabled(vm.apiId.isEmpty || vm.apiHash.isEmpty || vm.phone.isEmpty || vm.isLoading)
        }
    }
    
    private var telegramAuthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.telegramAPIKeysSaved)
                .font(.caption)
                .foregroundColor(theme.textSecondary)
            
            Button(action: { Task { await vm.startAuth() } }) {
                HStack {
                    if vm.isLoading { ProgressView().scaleEffect(0.8) }
                    Text(L10n.sendCode)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.07, green: 0.72, blue: 0.34))
            .disabled(vm.isLoading)
        }
    }
    
    private var telegramCodeEntry: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.codeSentDesc)
                .font(.caption)
                .foregroundColor(theme.textSecondary)
            
            TextField(L10n.confirmationCode, text: $vm.authCode)
                .textFieldStyle(.roundedBorder)
            #if os(iOS)
                .keyboardType(.numberPad)
            #endif
            
            Button(action: { Task { await vm.completeAuth() } }) {
                HStack {
                    if vm.isLoading { ProgressView().scaleEffect(0.8) }
                    Text(L10n.confirm)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.07, green: 0.72, blue: 0.34))
            .disabled(vm.authCode.isEmpty || vm.isLoading)
        }
    }
    
    private var telegram2FAEntry: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.telegram2FAHint)
                .font(.caption)
                .foregroundColor(theme.textSecondary)
            
            SecureField(L10n.twoFAPassword, text: $vm.twoFAPassword)
                .textFieldStyle(.roundedBorder)
            
            Button(action: { Task { await vm.completeAuth() } }) {
                HStack {
                    if vm.isLoading { ProgressView().scaleEffect(0.8) }
                    Text(L10n.confirm)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.07, green: 0.72, blue: 0.34))
            .disabled(vm.twoFAPassword.isEmpty || vm.isLoading)
        }
    }
    
    private var telegramConnected: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(L10n.connected)
                    .font(.subheadline.bold())
                    .foregroundColor(theme.textPrimary)
            }
            
            Text("\(vm.selectedChatsCount) \(L10n.chatsMonitored)")
                .font(.caption)
                .foregroundColor(theme.textSecondary)
            
            HStack(spacing: 12) {
                Button(L10n.selectChats) {
                    Task { await vm.loadChats() }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.07, green: 0.72, blue: 0.34))
                
                Button(L10n.disconnect, role: .destructive) {
                    Task { await vm.disconnect() }
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var telegramChatSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.selectChatsForMonitoring)
                    .font(.subheadline.bold())
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Button(L10n.done) {
                    Task { await vm.saveSelectedChats() }
                }
                .font(.subheadline.bold())
            }
            
            if vm.isLoading {
                ProgressView(L10n.loadingChats)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(vm.availableChats, id: \.id) { chat in
                    chatRow(chat: chat)
                }
            }
        }
    }
    
    private func chatRow(chat: MessengerChat) -> some View {
        Button(action: { vm.toggleChat(chat) }) {
            HStack {
                Image(systemName: chat.selected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(chat.selected ? .green : theme.textSecondary)
                
                VStack(alignment: .leading) {
                    Text(chat.title)
                        .font(.subheadline)
                        .foregroundColor(theme.textPrimary)
                    Text(chat.typeLabel)
                        .font(.caption2)
                        .foregroundColor(theme.textSecondary)
                }
                
                Spacer()
                
                if chat.unreadCount > 0 {
                    Text("\(chat.unreadCount)")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.red))
                        .foregroundColor(.white)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
    
    private func statusBadge(_ state: ConnectionState) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(state.color)
                .frame(width: 8, height: 8)
            Text(state.label)
                .font(.caption2)
                .foregroundColor(theme.textSecondary)
        }
    }
}

// MARK: - WhatsApp Setup Section

struct WhatsAppSetupSection: View {
    @Environment(\.theme) private var theme
    @StateObject private var vm = WhatsAppSetupVM()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.title2)
                    .foregroundColor(Color(red: 0.14, green: 0.80, blue: 0.44))
                Text("WhatsApp")
                    .font(.title3.bold())
                    .foregroundColor(theme.textPrimary)
                Spacer()
                statusBadge(vm.connectionState)
            }
            
            switch vm.setupPhase {
            case .notConfigured:
                whatsappCredentialsForm
                
            case .configured, .awaitingCode, .needs2FA:
                whatsappConnecting
                
            case .authorized:
                whatsappConnected
                
            case .chatSelection:
                whatsappChatSelection
            }
            
            if let error = vm.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 4)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBackground))
        .task { await vm.checkStatus() }
    }
    
    // --- Sub-views ---
    
    private var whatsappCredentialsForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.whatsappGreenAPIDesc)
                .font(.caption)
                .foregroundColor(theme.textSecondary)
            
            Link(L10n.whatsappRegisterGreenAPI, destination: URL(string: "https://green-api.com")!)
                .font(.caption.bold())
            
            Text(L10n.whatsappScanQRHint)
                .font(.caption)
                .foregroundColor(theme.textSecondary)
            
            TextField("Instance ID", text: $vm.instanceId)
                .textFieldStyle(.roundedBorder)
            
            TextField("API Token", text: $vm.apiToken)
                .textFieldStyle(.roundedBorder)
            
            Button(action: { Task { await vm.configure() } }) {
                HStack {
                    if vm.isLoading { ProgressView().scaleEffect(0.8) }
                    Text(L10n.connect)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.14, green: 0.80, blue: 0.44))
            .disabled(vm.instanceId.isEmpty || vm.apiToken.isEmpty || vm.isLoading)
        }
    }
    
    private var whatsappConnecting: some View {
        VStack(alignment: .leading, spacing: 12) {
            if vm.isLoading {
                ProgressView(L10n.checkingConnection)
            } else {
                Text(L10n.whatsappCheckingAuth)
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
                
                Button(L10n.checkStatus) {
                    Task { await vm.checkStatus() }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.14, green: 0.80, blue: 0.44))
            }
        }
    }
    
    private var whatsappConnected: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(L10n.connected)
                    .font(.subheadline.bold())
                    .foregroundColor(theme.textPrimary)
            }
            
            Text("\(vm.selectedChatsCount) \(L10n.chatsMonitored)")
                .font(.caption)
                .foregroundColor(theme.textSecondary)
            
            HStack(spacing: 12) {
                Button(L10n.selectChats) {
                    Task { await vm.loadChats() }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.14, green: 0.80, blue: 0.44))
                
                Button(L10n.disconnect, role: .destructive) {
                    Task { await vm.disconnect() }
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var whatsappChatSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.selectChatsForMonitoring)
                    .font(.subheadline.bold())
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Button(L10n.done) {
                    Task { await vm.saveSelectedChats() }
                }
                .font(.subheadline.bold())
            }
            
            if vm.isLoading {
                ProgressView(L10n.loadingChats)
                    .frame(maxWidth: .infinity)
            } else if vm.availableChats.isEmpty {
                Text(L10n.whatsappNoChats)
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
            } else {
                ForEach(vm.availableChats, id: \.id) { chat in
                    chatRow(chat: chat)
                }
            }
        }
    }
    
    private func chatRow(chat: MessengerChat) -> some View {
        Button(action: { vm.toggleChat(chat) }) {
            HStack {
                Image(systemName: chat.selected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(chat.selected ? .green : theme.textSecondary)
                
                VStack(alignment: .leading) {
                    Text(chat.title)
                        .font(.subheadline)
                        .foregroundColor(theme.textPrimary)
                    Text(chat.typeLabel)
                        .font(.caption2)
                        .foregroundColor(theme.textSecondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
    
    private func statusBadge(_ state: ConnectionState) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(state.color)
                .frame(width: 8, height: 8)
            Text(state.label)
                .font(.caption2)
                .foregroundColor(theme.textSecondary)
        }
    }
}

// MARK: - Shared Models & Enums

enum SetupPhase {
    case notConfigured
    case configured
    case awaitingCode
    case needs2FA
    case authorized
    case chatSelection
}

enum ConnectionState {
    case disconnected, connecting, connected, error
    
    var label: String {
        switch self {
        case .disconnected: return L10n.statusDisconnected
        case .connecting: return L10n.statusConnecting
        case .connected: return L10n.statusConnected
        case .error: return L10n.statusError
        }
    }
    
    var color: Color {
        switch self {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }
}

struct MessengerChat: Identifiable {
    let id: String
    let title: String
    let type: String
    var unreadCount: Int = 0
    var selected: Bool = false
    
    var typeLabel: String {
        switch type {
        case "private": return L10n.chatTypePrivate
        case "group": return L10n.chatTypeGroup
        case "supergroup": return L10n.chatTypeSupergroup
        case "channel": return L10n.chatTypeChannel
        default: return type
        }
    }
}

// MARK: - Telegram ViewModel

@MainActor
final class TelegramSetupVM: ObservableObject {
    @Published var setupPhase: SetupPhase = .notConfigured
    @Published var connectionState: ConnectionState = .disconnected
    @Published var isLoading = false
    @Published var error: String?
    
    @Published var apiId = ""
    @Published var apiHash = ""
    @Published var phone = ""
    @Published var authCode = ""
    @Published var twoFAPassword = ""
    @Published var phoneCodeHash = ""
    
    @Published var availableChats: [MessengerChat] = []
    @Published var selectedChatsCount = 0
    
    func checkStatus() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        guard let data = await apiGet(Config.Endpoints.telegramStatus) else {
            connectionState = .disconnected
            setupPhase = .notConfigured
            return
        }
        
        let configured = data["configured"] as? Bool ?? false
        let hasSession = data["has_session"] as? Bool ?? false
        selectedChatsCount = data["selected_chats_count"] as? Int ?? 0
        
        if configured && hasSession {
            setupPhase = .authorized
            connectionState = .connected
        } else if configured {
            setupPhase = .configured
            connectionState = .disconnected
        } else {
            setupPhase = .notConfigured
            connectionState = .disconnected
        }
    }
    
    func configure() async {
        guard let id = Int(apiId) else {
            error = L10n.errorApiIdNumber
            return
        }
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        let body: [String: Any] = ["api_id": id, "api_hash": apiHash, "phone": phone]
        guard let _ = await apiPost(Config.Endpoints.telegramConfigure, body: body) else {
            error = L10n.errorSaveSettingsBackend
            return
        }
        
        // Auto-start auth
        await startAuth()
    }
    
    func startAuth() async {
        isLoading = true
        error = nil
        connectionState = .connecting
        defer { isLoading = false }
        
        guard let data = await apiPost(Config.Endpoints.telegramAuthStart, body: [:]) else {
            error = L10n.errorBackendConnection
            connectionState = .error
            return
        }
        
        let status = data["status"] as? String ?? ""
        switch status {
        case "already_authorized":
            setupPhase = .authorized
            connectionState = .connected
        case "code_sent":
            phoneCodeHash = data["phone_code_hash"] as? String ?? ""
            setupPhase = .awaitingCode
            connectionState = .connecting
        default:
            error = data["error"] as? String ?? L10n.errorUnknown
            connectionState = .error
        }
    }
    
    func completeAuth() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        var body: [String: Any] = [
            "code": authCode,
            "phone_code_hash": phoneCodeHash,
        ]
        if !twoFAPassword.isEmpty {
            body["password"] = twoFAPassword
        }
        
        guard let data = await apiPost(Config.Endpoints.telegramAuthComplete, body: body) else {
            error = L10n.errorConnection
            return
        }
        
        let status = data["status"] as? String ?? ""
        switch status {
        case "authorized":
            setupPhase = .authorized
            connectionState = .connected
        case "need_2fa":
            setupPhase = .needs2FA
        default:
            error = data["error"] as? String ?? L10n.errorAuth
            connectionState = .error
        }
    }
    
    func loadChats() async {
        isLoading = true
        error = nil
        setupPhase = .chatSelection
        defer { isLoading = false }
        
        guard let data = await apiGet(Config.Endpoints.telegramChats),
              let chatsArray = data["chats"] as? [[String: Any]] else {
            error = L10n.errorLoadChats
            return
        }
        
        availableChats = chatsArray.map { dict in
            MessengerChat(
                id: String(describing: dict["id"] ?? "0"),
                title: dict["title"] as? String ?? "Unknown",
                type: dict["type"] as? String ?? "unknown",
                unreadCount: dict["unread_count"] as? Int ?? 0,
                selected: dict["selected"] as? Bool ?? false
            )
        }
    }
    
    func toggleChat(_ chat: MessengerChat) {
        if let idx = availableChats.firstIndex(where: { $0.id == chat.id }) {
            availableChats[idx].selected.toggle()
        }
    }
    
    func saveSelectedChats() async {
        let selectedIds = availableChats.filter(\.selected).map(\.id)
        let body: [String: Any] = ["chat_ids": selectedIds]
        _ = await apiPost(Config.Endpoints.telegramChatsSelect, body: body)
        selectedChatsCount = selectedIds.count
        setupPhase = .authorized
    }
    
    func disconnect() async {
        isLoading = true
        defer { isLoading = false }
        _ = await apiPost(Config.Endpoints.telegramDisconnect, body: [:])
        setupPhase = .notConfigured
        connectionState = .disconnected
        selectedChatsCount = 0
        availableChats = []
    }
}

// MARK: - WhatsApp ViewModel

@MainActor
final class WhatsAppSetupVM: ObservableObject {
    @Published var setupPhase: SetupPhase = .notConfigured
    @Published var connectionState: ConnectionState = .disconnected
    @Published var isLoading = false
    @Published var error: String?
    
    @Published var instanceId = ""
    @Published var apiToken = ""
    
    @Published var availableChats: [MessengerChat] = []
    @Published var selectedChatsCount = 0
    
    func checkStatus() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        guard let data = await apiGet(Config.Endpoints.whatsappStatus) else {
            connectionState = .disconnected
            setupPhase = .notConfigured
            return
        }
        
        let configured = data["configured"] as? Bool ?? false
        let authStatus = data["auth_status"] as? String ?? ""
        selectedChatsCount = data["selected_chats_count"] as? Int ?? 0
        
        if configured && authStatus == "authorized" {
            setupPhase = .authorized
            connectionState = .connected
        } else if configured {
            setupPhase = .configured
            connectionState = .connecting
        } else {
            setupPhase = .notConfigured
            connectionState = .disconnected
        }
    }
    
    func configure() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        let body: [String: Any] = ["instance_id": instanceId, "api_token": apiToken]
        guard let _ = await apiPost(Config.Endpoints.whatsappConfigure, body: body) else {
            error = L10n.errorSaveSettings
            return
        }
        
        // Check if the instance is already authorized
        await checkStatus()
    }
    
    func loadChats() async {
        isLoading = true
        error = nil
        setupPhase = .chatSelection
        defer { isLoading = false }
        
        guard let data = await apiGet(Config.Endpoints.whatsappChats),
              let chatsArray = data["chats"] as? [[String: Any]] else {
            error = L10n.errorLoadChatsQR
            return
        }
        
        availableChats = chatsArray.map { dict in
            MessengerChat(
                id: dict["id"] as? String ?? "",
                title: dict["title"] as? String ?? "Unknown",
                type: dict["type"] as? String ?? "unknown",
                selected: dict["selected"] as? Bool ?? false
            )
        }
    }
    
    func toggleChat(_ chat: MessengerChat) {
        if let idx = availableChats.firstIndex(where: { $0.id == chat.id }) {
            availableChats[idx].selected.toggle()
        }
    }
    
    func saveSelectedChats() async {
        let selectedIds = availableChats.filter(\.selected).map(\.id)
        let body: [String: Any] = ["chat_ids": selectedIds]
        _ = await apiPost(Config.Endpoints.whatsappChatsSelect, body: body)
        selectedChatsCount = selectedIds.count
        setupPhase = .authorized
    }
    
    func disconnect() async {
        isLoading = true
        defer { isLoading = false }
        _ = await apiPost(Config.Endpoints.whatsappDisconnect, body: [:])
        setupPhase = .notConfigured
        connectionState = .disconnected
        selectedChatsCount = 0
        availableChats = []
    }
}

// MARK: - Shared Network Helpers

private func apiGet(_ url: URL) async -> [String: Any]? {
    var request = URLRequest(url: url)
    request.timeoutInterval = 15
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    } catch {
        Logger.shared.warning("API GET \(url.path): \(error.localizedDescription)")
        return nil
    }
}

private func apiPost(_ url: URL, body: [String: Any]) async -> [String: Any]? {
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = 30
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    } catch {
        Logger.shared.warning("API POST \(url.path): \(error.localizedDescription)")
        return nil
    }
}
