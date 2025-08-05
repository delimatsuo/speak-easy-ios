import Foundation
import Network
import Combine

class NetworkReachability: ObservableObject {
    static let shared = NetworkReachability()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "network.monitor")
    private var currentPath: NWPath?
    
    @Published var isConnected: Bool = false
    @Published var isExpensive: Bool = false
    @Published var isConstrained: Bool = false
    @Published var connectionType: ConnectionType = .unknown
    @Published var networkStatus: NetworkStatus = .unknown
    
    private let statusPublisher = PassthroughSubject<NetworkStatus, Never>()
    var networkStatusUpdates: AnyPublisher<NetworkStatus, Never> {
        statusPublisher.eraseToAnyPublisher()
    }
    
    enum ConnectionType: String, CaseIterable {
        case wifi = "WiFi"
        case cellular = "Cellular"
        case ethernet = "Ethernet"
        case other = "Other"
        case unknown = "Unknown"
    }
    
    enum NetworkStatus: String {
        case connected = "Connected"
        case disconnected = "Disconnected"
        case connecting = "Connecting"
        case unknown = "Unknown"
    }
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateStatus(path)
            }
        }
        
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
    
    func checkConnectivity() async -> Bool {
        return await withCheckedContinuation { continuation in
            let testURL = URL(string: "https://www.google.com")!
            var request = URLRequest(url: testURL)
            request.timeoutInterval = 5.0
            request.httpMethod = "HEAD"
            
            URLSession.shared.dataTask(with: request) { _, response, error in
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(returning: false)
                }
            }.resume()
        }
    }
    
    func checkAPIConnectivity() async -> Bool {
        return await withCheckedContinuation { continuation in
            let testURL = URL(string: GeminiAPIConfig.baseURL)!
            var request = URLRequest(url: testURL)
            request.timeoutInterval = 10.0
            request.httpMethod = "HEAD"
            
            URLSession.shared.dataTask(with: request) { _, response, error in
                if let httpResponse = response as? HTTPURLResponse,
                   200...299 ~= httpResponse.statusCode {
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(returning: false)
                }
            }.resume()
        }
    }
    
    func getNetworkInfo() -> NetworkInfo {
        return NetworkInfo(
            isConnected: isConnected,
            connectionType: connectionType,
            isExpensive: isExpensive,
            isConstrained: isConstrained,
            status: networkStatus,
            lastUpdate: Date()
        )
    }
    
    func waitForConnection(timeout: TimeInterval = 30.0) async -> Bool {
        if isConnected {
            return true
        }
        
        return await withCheckedContinuation { continuation in
            var cancellable: AnyCancellable?
            var timeoutTask: Task<Void, Never>?
            
            cancellable = $isConnected
                .filter { $0 }
                .first()
                .sink { _ in
                    timeoutTask?.cancel()
                    continuation.resume(returning: true)
                }
            
            timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                cancellable?.cancel()
                continuation.resume(returning: false)
            }
        }
    }
    
    private func updateStatus(_ path: NWPath) {
        currentPath = path
        
        let wasConnected = isConnected
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained
        
        connectionType = determineConnectionType(path)
        
        let newStatus: NetworkStatus
        switch path.status {
        case .satisfied:
            newStatus = .connected
        case .unsatisfied:
            newStatus = .disconnected
        case .requiresConnection:
            newStatus = .connecting
        @unknown default:
            newStatus = .unknown
        }
        
        if networkStatus != newStatus {
            networkStatus = newStatus
            statusPublisher.send(newStatus)
        }
        
        if wasConnected != isConnected {
            NotificationCenter.default.post(
                name: .networkStatusChanged,
                object: nil,
                userInfo: [
                    "isConnected": isConnected,
                    "connectionType": connectionType.rawValue,
                    "isExpensive": isExpensive
                ]
            )
        }
        
        logNetworkChange(from: wasConnected, to: isConnected)
    }
    
    private func determineConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else if path.usesInterfaceType(.other) {
            return .other
        } else {
            return .unknown
        }
    }
    
    private func logNetworkChange(from wasConnected: Bool, to isConnected: Bool) {
        if wasConnected && !isConnected {
            print("Network disconnected")
        } else if !wasConnected && isConnected {
            print("Network connected via \(connectionType.rawValue)")
            if isExpensive {
                print("Warning: Using expensive connection")
            }
            if isConstrained {
                print("Warning: Connection is constrained")
            }
        }
    }
    
    func getConnectionQuality() -> ConnectionQuality {
        guard isConnected else { return .none }
        
        if isConstrained && isExpensive {
            return .poor
        } else if isExpensive {
            return .limited
        } else if connectionType == .wifi {
            return .excellent
        } else if connectionType == .cellular {
            return .good
        } else {
            return .good
        }
    }
    
    enum ConnectionQuality: String, CaseIterable {
        case none = "No Connection"
        case poor = "Poor"
        case limited = "Limited"
        case good = "Good"
        case excellent = "Excellent"
        
        var shouldLimitRequests: Bool {
            switch self {
            case .none, .poor:
                return true
            case .limited:
                return true
            case .good, .excellent:
                return false
            }
        }
        
        var recommendsBatching: Bool {
            switch self {
            case .none, .poor, .limited:
                return true
            case .good, .excellent:
                return false
            }
        }
    }
}

struct NetworkInfo {
    let isConnected: Bool
    let connectionType: NetworkReachability.ConnectionType
    let isExpensive: Bool
    let isConstrained: Bool
    let status: NetworkReachability.NetworkStatus
    let lastUpdate: Date
}

extension Notification.Name {
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
}

class NetworkMonitor {
    static let shared = NetworkMonitor()
    private let reachability = NetworkReachability.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupMonitoring()
    }
    
    private func setupMonitoring() {
        reachability.networkStatusUpdates
            .sink { [weak self] status in
                self?.handleNetworkStatusChange(status)
            }
            .store(in: &cancellables)
    }
    
    private func handleNetworkStatusChange(_ status: NetworkReachability.NetworkStatus) {
        switch status {
        case .connected:
            handleConnectionRestored()
        case .disconnected:
            handleConnectionLost()
        case .connecting:
            print("Network connecting...")
        case .unknown:
            print("Network status unknown")
        }
    }
    
    private func handleConnectionRestored() {
        print("Network connection restored")
        
        Task {
            if await reachability.checkAPIConnectivity() {
                NotificationCenter.default.post(name: .apiConnectivityRestored, object: nil)
            }
        }
    }
    
    private func handleConnectionLost() {
        print("Network connection lost")
        NotificationCenter.default.post(name: .apiConnectivityLost, object: nil)
    }
    
    func isOnlineAndReady() async -> Bool {
        guard reachability.isConnected else { return false }
        return await reachability.checkAPIConnectivity()
    }
    
    func shouldUseOfflineMode() -> Bool {
        let quality = reachability.getConnectionQuality()
        return quality == .none || quality == .poor
    }
    
    func shouldBatchRequests() -> Bool {
        let quality = reachability.getConnectionQuality()
        return quality.recommendsBatching
    }
}

extension Notification.Name {
    static let apiConnectivityRestored = Notification.Name("apiConnectivityRestored")
    static let apiConnectivityLost = Notification.Name("apiConnectivityLost")
}