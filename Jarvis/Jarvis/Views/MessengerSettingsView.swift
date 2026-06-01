import SwiftUI
import Combine

// MARK: - Messenger Integration Settings View
/// UI для настройки Telegram интеграции.
/// Позволяет: ввести API-ключи → авторизоваться → выбрать чаты для мониторинга.

struct MessengerSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    TelegramSetupSection()
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
            case .needsApiSetup:
                telegramApiSetup
                
            case .notConfigured:
                telegramPhoneEntry
                
            case .configured:
                telegramPhoneEntry
                
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
    
    private var telegramApiSetup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.telegramApiSetupDesc)
                .font(.caption)
                .foregroundColor(theme.textSecondary)
            
            Button(action: {
                if let url = URL(string: "https://my.telegram.org/apps") {
                    #if os(iOS)
                    UIApplication.shared.open(url)
                    #else
                    NSWorkspace.shared.open(url)
                    #endif
                }
            }) {
                HStack {
                    Image(systemName: "arrow.up.right.square")
                    Text(L10n.telegramOpenMyTelegram)
                }
                .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.blue)
            
            TextField("API ID", text: $vm.apiId)
                .textFieldStyle(.roundedBorder)
            #if os(iOS)
                .keyboardType(.numberPad)
            #endif
            
            TextField("API Hash", text: $vm.apiHash)
                .textFieldStyle(.roundedBorder)
            
            Button(action: { Task { await vm.saveApiCredentials() } }) {
                HStack {
                    if vm.isLoading { ProgressView().scaleEffect(0.8) }
                    Text(L10n.save)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.07, green: 0.72, blue: 0.34))
            .disabled(vm.apiId.isEmpty || vm.apiHash.isEmpty || vm.isLoading)
        }
    }
    
    private var telegramPhoneEntry: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.telegramEnterPhone)
                .font(.caption)
                .foregroundColor(theme.textSecondary)
            
            TextField(L10n.phoneNumber, text: $vm.phone)
                .textFieldStyle(.roundedBorder)
            #if os(iOS)
                .keyboardType(.phonePad)
            #endif
            
            Button(action: { Task { await vm.sendCode() } }) {
                HStack {
                    if vm.isLoading { ProgressView().scaleEffect(0.8) }
                    Text(L10n.sendCode)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.07, green: 0.72, blue: 0.34))
            .disabled(vm.phone.count < 5 || vm.isLoading)
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
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(theme.textSecondary)
                TextField(L10n.searchChats, text: $vm.searchQuery)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                if !vm.searchQuery.isEmpty {
                    Button(action: {
                        vm.searchQuery = ""
                        vm.searchResults = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(theme.background))
            .onChange(of: vm.searchQuery) { _, newValue in
                vm.onSearchChanged(newValue)
            }
            
            if vm.isLoading {
                ProgressView(L10n.loadingChats)
                    .frame(maxWidth: .infinity)
            } else {
                let chatsToShow = vm.searchResults ?? vm.availableChats
                if chatsToShow.isEmpty {
                    Text(vm.searchResults != nil ? L10n.noChatsFound : L10n.loadingChats)
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(chatsToShow, id: \.id) { chat in
                                chatRow(chat: chat)
                            }
                        }
                    }
                    .frame(maxHeight: 400)
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

// MARK: - Shared Models & Enums

enum SetupPhase {
    case needsApiSetup
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
    @Published var searchQuery = ""
    @Published var searchResults: [MessengerChat]? = nil
    private var searchTask: Task<Void, Never>?
    
    func checkStatus() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        guard let data = await apiGet(Config.Endpoints.telegramStatus) else {
            connectionState = .disconnected
            setupPhase = .notConfigured
            return
        }
        
        let apiConfigured = data["api_configured"] as? Bool ?? false
        let configured = data["configured"] as? Bool ?? false
        let hasSession = data["has_session"] as? Bool ?? false
        selectedChatsCount = data["selected_chats_count"] as? Int ?? 0
        
        if !apiConfigured {
            setupPhase = .needsApiSetup
            connectionState = .disconnected
        } else if configured && hasSession {
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
    
    func saveApiCredentials() async {
        guard let idNum = Int(apiId) else {
            error = L10n.apiIdMustBeNumber
            return
        }
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        let body: [String: Any] = ["api_id": idNum, "api_hash": apiHash]
        guard let data = await apiPost(Config.Endpoints.telegramApiCredentials, body: body),
              let status = data["status"] as? String, status == "ok" else {
            error = L10n.errorBackendConnection
            return
        }
        setupPhase = .notConfigured
    }
    
    func sendCode() async {
        isLoading = true
        error = nil
        connectionState = .connecting
        defer { isLoading = false }
        
        let body: [String: Any] = ["phone": phone]
        guard let data = await apiPost(Config.Endpoints.telegramConfigure, body: body) else {
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
        searchQuery = ""
        searchResults = nil
        setupPhase = .chatSelection
        defer { isLoading = false }
        
        // Load more chats by default (200 instead of 50)
        var components = URLComponents(url: Config.Endpoints.telegramChats, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "limit", value: "200")]
        guard let url = components.url,
              let data = await apiGet(url),
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
        // Toggle in both lists to keep them in sync
        if let idx = availableChats.firstIndex(where: { $0.id == chat.id }) {
            availableChats[idx].selected.toggle()
        }
        if var results = searchResults,
           let idx = results.firstIndex(where: { $0.id == chat.id }) {
            results[idx].selected.toggle()
            searchResults = results
        }
    }
    
    func onSearchChanged(_ query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            searchResults = nil
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000) // debounce 0.4s
            guard !Task.isCancelled else { return }
            await searchChats(query: trimmed)
        }
    }
    
    func searchChats(query: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        var components = URLComponents(url: Config.Endpoints.telegramChatsSearch, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let url = components.url,
              let data = await apiGet(url),
              let chatsArray = data["chats"] as? [[String: Any]] else {
            searchResults = []
            return
        }
        
        // Merge selection state from availableChats
        let selectedIds = Set(availableChats.filter(\.selected).map(\.id))
        searchResults = chatsArray.map { dict in
            let id = String(describing: dict["id"] ?? "0")
            return MessengerChat(
                id: id,
                title: dict["title"] as? String ?? "Unknown",
                type: dict["type"] as? String ?? "unknown",
                unreadCount: dict["unread_count"] as? Int ?? 0,
                selected: (dict["selected"] as? Bool ?? false) || selectedIds.contains(id)
            )
        }
    }
    
    func saveSelectedChats() async {
        // Merge selected from both main list and search results
        var selectedIds = Set(availableChats.filter(\.selected).map(\.id))
        if let results = searchResults {
            for chat in results where chat.selected {
                selectedIds.insert(chat.id)
            }
        }
        let body: [String: Any] = ["chat_ids": Array(selectedIds)]
        _ = await apiPost(Config.Endpoints.telegramChatsSelect, body: body)
        selectedChatsCount = selectedIds.count
        searchQuery = ""
        searchResults = nil
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

// MARK: - Shared Network Helpers

private func apiGet(_ url: URL) async -> [String: Any]? {
    var request = Config.authorizedRequest(url: url)
    request.timeoutInterval = 15
    do {
        let (data, response) = try await Config.urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { return nil }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            Logger.shared.warning("API GET \(url.path) HTTP \(http.statusCode): \(body)")
            return nil
        }
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    } catch {
        Logger.shared.warning("API GET \(url.path): \(error)")
        return nil
    }
}

private func apiPost(_ url: URL, body: [String: Any]) async -> [String: Any]? {
    var request = Config.authorizedRequest(url: url, method: "POST")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = 30
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    do {
        let (data, response) = try await Config.urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { return nil }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            Logger.shared.warning("API POST \(url.path) HTTP \(http.statusCode): \(body)")
            return nil
        }
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    } catch {
        Logger.shared.warning("API POST \(url.path): \(error.localizedDescription)")
        return nil
    }
}
