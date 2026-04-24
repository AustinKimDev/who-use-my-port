import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: PortMonitorViewModel
    var isCompact: Bool

    var body: some View {
        content
        .onAppear {
            if viewModel.processes.isEmpty, !viewModel.isScanning {
                viewModel.scan()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isCompact {
            CompactMenuBarView(viewModel: viewModel)
        } else {
            VStack(spacing: 0) {
                QueryBar(viewModel: viewModel, isCompact: false)
                    .padding()

                Divider()

                regularLayout

                Divider()
                StatusBar(viewModel: viewModel)
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

private struct CompactMenuBarView: View {
    @ObservedObject var viewModel: PortMonitorViewModel

    var body: some View {
        VStack(spacing: 0) {
            compactSearch
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 8)

            CompactStatus(viewModel: viewModel)
                .padding(.horizontal, 10)
                .padding(.bottom, 8)

            Divider()

            CompactProcessList(viewModel: viewModel)
                .frame(height: 218)

            Divider()

            CompactProcessInspector(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var compactSearch: some View {
        HStack(spacing: 6) {
            TextField("Port", text: $viewModel.queryText)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .onSubmit {
                    viewModel.scan()
                }

            Button {
                viewModel.scan()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(viewModel.isScanning)
            .help("Scan")
        }
    }
}

private struct CompactStatus: View {
    @ObservedObject var viewModel: PortMonitorViewModel

    var body: some View {
        HStack(spacing: 6) {
            if viewModel.isScanning {
                ProgressView()
                    .controlSize(.small)
            }

            Text(viewModel.errorMessage ?? viewModel.statusText)
                .font(.caption2)
                .foregroundStyle(viewModel.errorMessage == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.red))
                .lineLimit(1)

            Spacer()

            Text("\(viewModel.processes.count)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

private struct CompactProcessList: View {
    @ObservedObject var viewModel: PortMonitorViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                if viewModel.processes.isEmpty, !viewModel.isScanning {
                    ContentUnavailableView("No Processes", systemImage: "network.slash")
                        .font(.caption)
                        .padding(.top, 42)
                } else {
                    ForEach(viewModel.processes) { process in
                        CompactProcessRow(
                            process: process,
                            isSelected: viewModel.selectedPID == process.pid
                        ) {
                            viewModel.selectedPID = process.pid
                        }
                    }
                }
            }
            .padding(6)
        }
    }
}

private struct CompactProcessRow: View {
    var process: PortProcess
    var isSelected: Bool
    var select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(process.command)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)

                    Text("Ports \(process.portSummary)  PID \(process.pid)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                Text(process.protocolsSummary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

private struct CompactProcessInspector: View {
    @ObservedObject var viewModel: PortMonitorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let process = viewModel.selectedProcess {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(process.command)
                            .font(.callout.weight(.semibold))
                            .lineLimit(1)

                        Text("PID \(process.pid)  \(process.user.isEmpty ? "Unknown" : process.user)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    compactActionButtons(process)
                }

                compactMetadata(process)

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(process.connections) { connection in
                            HStack(spacing: 6) {
                                Text(connection.protocolName)
                                    .font(.caption2.weight(.semibold))
                                    .frame(width: 38, alignment: .leading)

                                Text(connection.displayState)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 62, alignment: .leading)

                                Text(connection.name)
                                    .font(.caption2.monospaced())
                                    .lineLimit(1)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ContentUnavailableView("Select a Process", systemImage: "info.circle")
                    .font(.caption)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(10)
    }

    private func compactActionButtons(_ process: PortProcess) -> some View {
        HStack(spacing: 4) {
            Button {
                copyDetails(process)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .help("Copy")

            Button {
                revealExecutable(process)
            } label: {
                Image(systemName: "folder")
            }
            .disabled(process.executablePath == nil)
            .help("Reveal")

            Button(role: .destructive) {
                viewModel.terminateSelected(force: false)
            } label: {
                Image(systemName: "xmark.circle")
            }
            .help("Terminate")

            Button(role: .destructive) {
                viewModel.terminateSelected(force: true)
            } label: {
                Image(systemName: "exclamationmark.triangle")
            }
            .help("Force Kill")
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
    }

    private func compactMetadata(_ process: PortProcess) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(process.executablePath ?? "Unknown executable")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .textSelection(.enabled)

            Text(process.arguments ?? "No arguments")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .textSelection(.enabled)
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
