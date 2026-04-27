import Foundation

@MainActor
final class PortMonitorViewModel: ObservableObject {
    private static let queryDefaultsKey = "PortMonitorQueryText"

    @Published var queryText: String {
        didSet {
            UserDefaults.standard.set(queryText, forKey: Self.queryDefaultsKey)
        }
    }

    @Published var processes: [PortProcess] = []
    @Published var ports: [MonitoredPort] = []
    @Published var aiRegistrations: [PortRegistration] = []
    @Published var focusedPort: Int?
    @Published var selectedPIDs: Set<Int> = []
    @Published var focusedPID: Int?
    @Published var isScanning = false
    @Published var statusText = "Ready"
    @Published var errorMessage: String?

    private let scanner = PortScanner()
    private let processController = ProcessController()
    private let registryStore = PortRegistryStore()
    private var isRefreshing = false

    var selectedProcess: PortProcess? {
        if let focusedProcess {
            return focusedProcess
        }

        return processes.first { selectedPIDs.contains($0.pid) }
    }

    var selectedPort: MonitoredPort? {
        if let focusedPort {
            return ports.first { $0.port == focusedPort }
        }

        return ports.first
    }

    var focusedProcess: PortProcess? {
        guard let focusedPID else { return nil }
        return processes.first { $0.pid == focusedPID }
    }

    var selectedProcesses: [PortProcess] {
        processes.filter { selectedPIDs.contains($0.pid) }
    }

    init() {
        queryText = UserDefaults.standard.string(forKey: Self.queryDefaultsKey) ?? "3000"
        aiRegistrations = Self.sortRegistrations(registryStore.load())
    }

    func scan() {
        performScan(isUserInitiated: true)
    }

    func refreshLivePorts() {
        performScan(isUserInitiated: false)
    }

    private func performScan(isUserInitiated: Bool) {
        if isRefreshing {
            return
        }

        isRefreshing = true
        errorMessage = nil
        if isUserInitiated {
            isScanning = true
            statusText = "Scanning..."
        }

        Task {
            defer {
                isRefreshing = false
                if isUserInitiated {
                    isScanning = false
                }
            }

            do {
                let query = try PortQuery.parse(queryText)
                let foundProcesses = try await scanner.scan(query)
                let registrations = Self.sortRegistrations(registryStore.load())
                let monitoredPorts = Self.makeMonitoredPorts(
                    query: query,
                    processes: foundProcesses,
                    registrations: registrations
                )

                processes = foundProcesses
                aiRegistrations = registrations
                ports = monitoredPorts
                selectedPIDs = selectedPIDs.intersection(Set(foundProcesses.map(\.pid)))
                let foundPIDs = Set(foundProcesses.map(\.pid))
                focusedPID = foundPIDs.contains(focusedPID ?? -1) ? focusedPID : foundProcesses.first?.pid
                let foundPorts = Set(monitoredPorts.map(\.port))
                focusedPort = foundPorts.contains(focusedPort ?? -1) ? focusedPort : monitoredPorts.first?.port
                statusText = monitoredPorts.isEmpty
                    ? "No ports found for \(query.rawValue)"
                    : "Tracking \(monitoredPorts.count) port\(monitoredPorts.count == 1 ? "" : "s")"
            } catch {
                if !isUserInitiated {
                    return
                }

                processes = []
                ports = []
                selectedPIDs = []
                focusedPID = nil
                focusedPort = nil
                statusText = "Scan failed"
                errorMessage = error.localizedDescription
            }
        }
    }

    func reloadRegistry() {
        guard let query = try? PortQuery.parse(queryText) else { return }
        let registrations = Self.sortRegistrations(registryStore.load())
        aiRegistrations = registrations

        let monitoredPorts = Self.makeMonitoredPorts(
            query: query,
            processes: processes,
            registrations: registrations
        )
        ports = monitoredPorts

        let foundPorts = Set(monitoredPorts.map(\.port))
        focusedPort = foundPorts.contains(focusedPort ?? -1) ? focusedPort : monitoredPorts.first?.port
    }

    func applyPreset(_ preset: PortPreset) {
        queryText = preset.query
        scan()
    }

    func focus(pid: Int) {
        focusedPID = pid
    }

    func focus(port: Int) {
        focusedPort = port
        focusedPID = ports.first { $0.port == port }?.primaryProcess?.pid
    }

    func inspect(registration: PortRegistration) {
        queryText = "\(registration.port)"
        focusedPort = registration.port
        scan()
    }

    func toggleSelection(pid: Int, extendRange: Bool) {
        if extendRange,
           let anchorPID = focusedPID,
           let anchorIndex = processes.firstIndex(where: { $0.pid == anchorPID }),
           let targetIndex = processes.firstIndex(where: { $0.pid == pid }) {
            let bounds = min(anchorIndex, targetIndex)...max(anchorIndex, targetIndex)
            for process in processes[bounds] {
                selectedPIDs.insert(process.pid)
            }
            focusedPID = pid
            return
        }

        if selectedPIDs.contains(pid) {
            selectedPIDs.remove(pid)
        } else {
            selectedPIDs.insert(pid)
        }

        focusedPID = pid
    }

    func clearSelection() {
        selectedPIDs = []
    }

    func terminateSelected(force: Bool) {
        terminate(processes: selectedProcesses, force: force)
    }

    func terminate(process: PortProcess, force: Bool) {
        terminate(processes: [process], force: force)
    }

    private func terminate(processes targets: [PortProcess], force: Bool) {
        guard !targets.isEmpty else { return }

        let targetPIDs = targets.map(\.pid)
        let label = targets.count == 1 ? "PID \(targetPIDs[0])" : "\(targets.count) processes"
        errorMessage = nil
        statusText = force ? "Force killing \(label)..." : "Terminating \(label)..."

        Task {
            do {
                for pid in targetPIDs {
                    try await processController.terminate(pid: pid, force: force)
                }

                selectedPIDs.subtract(targetPIDs)
                if targetPIDs.contains(focusedPID ?? -1) {
                    focusedPID = nil
                }
                statusText = force ? "Force killed \(label)" : "Terminated \(label)"
                scan()
            } catch {
                statusText = "Terminate failed"
                errorMessage = error.localizedDescription
            }
        }
    }

    private static func makeMonitoredPorts(
        query: PortQuery,
        processes: [PortProcess],
        registrations: [PortRegistration]
    ) -> [MonitoredPort] {
        var ports = Set<Int>()

        if let expandedPorts = query.expandedPorts() {
            ports.formUnion(expandedPorts)
        }

        for process in processes {
            ports.formUnion(process.connections.compactMap(\.localPort))
        }

        for registration in registrations where query.contains(port: registration.port) {
            ports.insert(registration.port)
        }

        return ports.sorted().map { port in
            MonitoredPort(
                port: port,
                processes: processes.compactMap { process in
                    let matchingConnections = process.connections.filter { $0.localPort == port }
                    guard !matchingConnections.isEmpty else { return nil }

                    var filteredProcess = process
                    filteredProcess.connections = matchingConnections
                    return filteredProcess
                },
                registrations: registrations
                    .filter { $0.port == port }
                    .sorted { $0.updatedAt > $1.updatedAt }
            )
        }
    }

    private static func sortRegistrations(_ registrations: [PortRegistration]) -> [PortRegistration] {
        registrations.sorted {
            if $0.isStale != $1.isStale {
                return !$0.isStale
            }

            if $0.updatedAt != $1.updatedAt {
                return $0.updatedAt > $1.updatedAt
            }

            return $0.port < $1.port
        }
    }
}
