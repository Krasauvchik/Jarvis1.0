import Foundation
import Network
import Combine

/// Network connectivity monitor (inspired by Task-Sync-Pro connectivity handling)
@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published private(set) var isConnected = true
    @Published private(set) var connectionType: ConnectionType = .unknown

    /// Обновить состояние из pathUpdateHandler (вызывается на MainActor).
    fileprivate func applyPathUpdate(connected: Bool, connectionType: ConnectionType) {
        self.isConnected = connected
        self.connectionType = connectionType
    }
    
    enum ConnectionType: String {
        case wifi = "Wi-Fi"
        case cellular = "Cellular"
        case wired = "Ethernet"
        case unknown = "Unknown"
    }
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { path in
            let connected = path.status == .satisfied
            let type = Self.connectionType(from: path)
            Task { @MainActor in
                NetworkMonitor.shared.applyPathUpdate(connected: connected, connectionType: type)
            }
        }
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
    
    nonisolated private static func connectionType(from path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wired
        }
        return .unknown
    }
}
