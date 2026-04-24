import SwiftUI

@main
struct WhoUseMyPortApp: App {
    @StateObject private var viewModel = PortMonitorViewModel()

    var body: some Scene {
        WindowGroup("Who Use My Port") {
            ContentView(viewModel: viewModel, isCompact: false)
                .frame(minWidth: 920, minHeight: 600)
        }
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
                .frame(width: 540, height: 620)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class PortMonitorViewModel: ObservableObject {
    @Published var queryText = "3000"
    @Published var processes: [PortProcess] = []
    @Published var selectedPID: Int?
    @Published var isScanning = false
    @Published var statusText = "Ready"
    @Published var errorMessage: String?

    private let scanner = PortScanner()
    private let processController = ProcessController()

    var selectedProcess: PortProcess? {
        guard let selectedPID else { return processes.first }
        return processes.first { $0.pid == selectedPID }
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
                selectedPID = foundProcesses.first?.pid
                statusText = foundProcesses.isEmpty
                    ? "No processes found for \(query.rawValue)"
                    : "Found \(foundProcesses.count) process\(foundProcesses.count == 1 ? "" : "es")"
            } catch {
                processes = []
                selectedPID = nil
                statusText = "Scan failed"
                errorMessage = error.localizedDescription
            }

            isScanning = false
        }
    }

    func terminateSelected(force: Bool) {
        guard let process = selectedProcess else { return }
        errorMessage = nil
        statusText = force ? "Force killing PID \(process.pid)..." : "Terminating PID \(process.pid)..."

        Task {
            do {
                try await processController.terminate(pid: process.pid, force: force)
                statusText = force ? "Force killed PID \(process.pid)" : "Terminated PID \(process.pid)"
                scan()
            } catch {
                statusText = "Terminate failed"
                errorMessage = error.localizedDescription
            }
        }
    }
}
