import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: PortMonitorViewModel
    var isCompact: Bool

    var body: some View {
        VStack(spacing: 0) {
            QueryBar(viewModel: viewModel, isCompact: isCompact)
                .padding()

            Divider()

            if isCompact {
                compactLayout
            } else {
                regularLayout
            }

            Divider()
            StatusBar(viewModel: viewModel)
        }
        .onAppear {
            if viewModel.processes.isEmpty, !viewModel.isScanning {
                viewModel.scan()
            }
        }
    }

    private var regularLayout: some View {
        HStack(spacing: 0) {
            ProcessList(viewModel: viewModel)
                .frame(minWidth: 340, idealWidth: 380)

            Divider()

            DetailPanel(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var compactLayout: some View {
        VStack(spacing: 0) {
            ProcessList(viewModel: viewModel)
                .frame(height: 240)

            Divider()

            DetailPanel(viewModel: viewModel)
        }
    }
}

private struct QueryBar: View {
    @ObservedObject var viewModel: PortMonitorViewModel
    var isCompact: Bool

    var body: some View {
        HStack(spacing: 10) {
            TextField("Port or range", text: $viewModel.queryText)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    viewModel.scan()
                }

            Button {
                viewModel.scan()
            } label: {
                Label(viewModel.isScanning ? "Scanning" : "Scan", systemImage: "magnifyingglass")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isScanning)

            if !isCompact {
                Text("Examples: 3000, 3000-3010, 3000, 5000-5010")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ProcessList: View {
    @ObservedObject var viewModel: PortMonitorViewModel

    var body: some View {
        List(selection: $viewModel.selectedPID) {
            ForEach(viewModel.processes) { process in
                ProcessRow(process: process)
                    .tag(process.pid)
            }
        }
        .overlay {
            if viewModel.processes.isEmpty, !viewModel.isScanning {
                ContentUnavailableView(
                    "No Processes",
                    systemImage: "network.slash",
                    description: Text("Run a scan to inspect ports.")
                )
            }
        }
    }
}

private struct ProcessRow: View {
    var process: PortProcess

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(process.command)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Text("PID \(process.pid)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Label(process.portSummary, systemImage: "number")
                Label(process.protocolsSummary, systemImage: "arrow.left.arrow.right")
                if !process.user.isEmpty {
                    Label(process.user, systemImage: "person")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}

private struct DetailPanel: View {
    @ObservedObject var viewModel: PortMonitorViewModel

    var body: some View {
        Group {
            if let process = viewModel.selectedProcess {
                VStack(alignment: .leading, spacing: 16) {
                    detailHeader(process)

                    Divider()

                    processMetadata(process)

                    Divider()

                    connectionsTable(process)

                    Spacer(minLength: 0)
                }
                .padding()
            } else {
                ContentUnavailableView(
                    "Select a Process",
                    systemImage: "info.circle",
                    description: Text("Choose a result to inspect process details.")
                )
            }
        }
    }

    private func detailHeader(_ process: PortProcess) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(process.command)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)

                Text("PID \(process.pid)")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                copyDetails(process)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            Button {
                revealExecutable(process)
            } label: {
                Label("Reveal", systemImage: "folder")
            }
            .disabled(process.executablePath == nil)

            Button(role: .destructive) {
                viewModel.terminateSelected(force: false)
            } label: {
                Label("Terminate", systemImage: "xmark.circle")
            }

            Button(role: .destructive) {
                viewModel.terminateSelected(force: true)
            } label: {
                Label("Force Kill", systemImage: "exclamationmark.triangle")
            }
        }
    }

    private func processMetadata(_ process: PortProcess) -> some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 8) {
            GridRow {
                Text("User").foregroundStyle(.secondary)
                Text(process.user.isEmpty ? "Unknown" : process.user)
            }
            GridRow {
                Text("Ports").foregroundStyle(.secondary)
                Text(process.portSummary)
            }
            GridRow {
                Text("Executable").foregroundStyle(.secondary)
                Text(process.executablePath ?? "Unknown")
                    .textSelection(.enabled)
                    .lineLimit(2)
            }
            GridRow {
                Text("Arguments").foregroundStyle(.secondary)
                Text(process.arguments ?? "Unknown")
                    .textSelection(.enabled)
                    .lineLimit(4)
            }
        }
        .font(.callout)
    }

    private func connectionsTable(_ process: PortProcess) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Connections")
                .font(.headline)

            Table(process.connections) {
                TableColumn("Protocol") { connection in
                    Text(connection.protocolName)
                }
                TableColumn("State") { connection in
                    Text(connection.displayState)
                }
                TableColumn("Name") { connection in
                    Text(connection.name)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func copyDetails(_ process: PortProcess) {
        let connections = process.connections
            .map { "- \($0.protocolName) \($0.displayState) \($0.name)" }
            .joined(separator: "\n")

        let text = """
        Command: \(process.command)
        PID: \(process.pid)
        User: \(process.user)
        Ports: \(process.portSummary)
        Executable: \(process.executablePath ?? "Unknown")
        Arguments: \(process.arguments ?? "Unknown")

        Connections:
        \(connections)
        """

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func revealExecutable(_ process: PortProcess) {
        guard let executablePath = process.executablePath else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: executablePath)])
    }
}

private struct StatusBar: View {
    @ObservedObject var viewModel: PortMonitorViewModel

    var body: some View {
        HStack(spacing: 8) {
            if viewModel.isScanning {
                ProgressView()
                    .controlSize(.small)
            }

            Text(viewModel.errorMessage ?? viewModel.statusText)
                .font(.caption)
                .foregroundStyle(viewModel.errorMessage == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.red))
                .lineLimit(2)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
