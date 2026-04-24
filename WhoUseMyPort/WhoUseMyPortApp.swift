import SwiftUI

@main
struct WhoUseMyPortApp: App {
    @StateObject private var viewModel = PortMonitorViewModel()

    var body: some Scene {
        WindowGroup("Who Use My Port") {
            ContentView(viewModel: viewModel, isCompact: false)
                .frame(minWidth: 920, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Scan") {
                    viewModel.scan()
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }

        MenuBarExtra("Ports", systemImage: "point.3.connected.trianglepath.dotted") {
            ContentView(viewModel: viewModel, isCompact: true)
                .frame(minWidth: 340, idealWidth: 380, maxWidth: 560, minHeight: 260, idealHeight: 350, maxHeight: 620)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class PortMonitorViewModel: ObservableObject {
    private static let queryDefaultsKey = "PortMonitorQueryText"

    @Published var queryText: String {
        didSet {
            UserDefaults.standard.set(queryText, forKey: Self.queryDefaultsKey)
        }
    }

    @Published var processes: [PortProcess] = []
    @Published var selectedPIDs: Set<Int> = []
    @Published var focusedPID: Int?
    @Published var isScanning = false
    @Published var statusText = "Ready"
    @Published var errorMessage: String?

    private let scanner = PortScanner()
    private let processController = ProcessController()

    var selectedProcess: PortProcess? {
        if let focusedPID, selectedPIDs.contains(focusedPID) {
            return processes.first { $0.pid == focusedPID }
        }

        return processes.first { selectedPIDs.contains($0.pid) }
    }

    var selectedProcesses: [PortProcess] {
        processes.filter { selectedPIDs.contains($0.pid) }
    }

    init() {
        queryText = UserDefaults.standard.string(forKey: Self.queryDefaultsKey) ?? "3000"
    }

    func scan() {
        errorMessage = nil
        isScanning = true
        statusText = "Scanning..."

        Task {
            do {
                let query = try PortQuery.parse(queryText)
                let foundProcesses = try await scanner.scan(query)

                processes = foundProcesses
                selectedPIDs = selectedPIDs.intersection(Set(foundProcesses.map(\.pid)))
                focusedPID = selectedPIDs.contains(focusedPID ?? -1) ? focusedPID : selectedPIDs.first
                statusText = foundProcesses.isEmpty
                    ? "No processes found for \(query.rawValue)"
                    : "Found \(foundProcesses.count) process\(foundProcesses.count == 1 ? "" : "es")"
            } catch {
                processes = []
                selectedPIDs = []
                focusedPID = nil
                statusText = "Scan failed"
                errorMessage = error.localizedDescription
            }

            isScanning = false
        }
    }

    func applyPreset(_ preset: PortPreset) {
        queryText = preset.query
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
            focusedPID = selectedPIDs.first
        } else {
            selectedPIDs.insert(pid)
            focusedPID = pid
        }
    }

    func clearSelection() {
        selectedPIDs = []
        focusedPID = nil
    }

    func terminateSelected(force: Bool) {
        let targets = selectedProcesses
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
                focusedPID = selectedPIDs.first
                statusText = force ? "Force killed \(label)" : "Terminated \(label)"
                scan()
            } catch {
                statusText = "Terminate failed"
                errorMessage = error.localizedDescription
            }
        }
    }
}
