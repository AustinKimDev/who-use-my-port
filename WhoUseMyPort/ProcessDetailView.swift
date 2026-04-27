import AppKit
import SwiftUI

struct DetailPanel: View {
    @ObservedObject var viewModel: PortMonitorViewModel

    var body: some View {
        Group {
            if let port = viewModel.selectedPort {
                ScrollView {
                    VStack(alignment: .leading, spacing: 9) {
                        PortInspectorTitle(port: port)

                        if !viewModel.selectedProcesses.isEmpty {
                            BulkSelectionBar(viewModel: viewModel)
                        }

                        portSummary(port)
                        registrySection(port)
                        processSection(port)
                        connectionsSection(port)
                    }
                    .padding(12)
                }
            } else {
                NativeEmptyState(
                    title: "Select a port",
                    systemImage: "info.circle",
                    message: "Scan a port pack, then select a port to inspect its owner, process, and AI usage registration."
                )
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .surfacePanel(cornerRadius: 10)
    }

    private func portSummary(_ port: MonitoredPort) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppTheme.elevatedFill)

                Image(systemName: port.statusSystemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(statusTint(port))
            }
            .frame(width: 38, height: 38)
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(AppTheme.panelStroke))

            VStack(alignment: .leading, spacing: 4) {
                Text("Port \(port.port)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    StatusBadge(text: port.statusTitle, tint: statusTint(port))

                    Text(port.ownerSummary)
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(1)
                }
            }

            Spacer()

            actionButtons(port)
        }
    }

    private func actionButtons(_ port: MonitoredPort) -> some View {
        HStack(spacing: 5) {
            IconActionButton(systemImage: "doc.on.doc", help: "Copy port report") {
                copyReport(port)
            }

            IconActionButton(systemImage: "terminal", help: "Copy kill command", isDisabled: port.primaryProcess == nil) {
                copyKillCommand(port)
            }

            IconActionButton(systemImage: "folder", help: "Open project", isDisabled: port.primaryRegistration == nil) {
                openProject(port)
            }

            IconActionButton(systemImage: "xmark.circle", help: "Terminate", tint: AppTheme.danger, isDisabled: port.primaryProcess == nil) {
                guard let process = port.primaryProcess else { return }
                viewModel.terminate(process: process, force: false)
            }

            IconActionButton(systemImage: "exclamationmark.triangle", help: "Force Kill", tint: AppTheme.amber, isDisabled: port.primaryProcess == nil) {
                guard let process = port.primaryProcess else { return }
                viewModel.terminate(process: process, force: true)
            }
        }
    }

    private func registrySection(_ port: MonitoredPort) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("AI Usage")
                .font(.callout.weight(.semibold))
                .foregroundStyle(AppTheme.ink)

            if port.registrations.isEmpty {
                MetadataLine(title: "Owner", value: "Not registered")
            } else {
                ForEach(port.registrations) { registration in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label(registration.tool, systemImage: "sparkles")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.ink)

                            Spacer()

                            StatusBadge(text: registration.isStale ? "STALE" : "LIVE", tint: registration.isStale ? AppTheme.amber : AppTheme.mint)
                        }

                        MetadataLine(title: "Project", value: registration.projectPath, lineLimit: 2)
                        MetadataLine(title: "Purpose", value: registration.purpose ?? "Unknown")
                        MetadataLine(title: "Command", value: registration.command ?? "Unknown", lineLimit: 2)
                    }
                    .padding(9)
                    .background(AppTheme.elevatedFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(AppTheme.panelStroke))
                }
            }
        }
    }

    private func processSection(_ port: MonitoredPort) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Process")
                .font(.callout.weight(.semibold))
                .foregroundStyle(AppTheme.ink)

            if port.processes.isEmpty {
                MetadataLine(title: "Status", value: port.isReserved ? "Reserved, but no matching local listener was found." : "Available")
                    .padding(9)
                    .background(AppTheme.elevatedFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                ForEach(port.processes) { process in
                    VStack(alignment: .leading, spacing: 6) {
                        MetadataLine(title: "Command", value: process.command)
                        MetadataLine(title: "PID", value: "\(process.pid)")
                        MetadataLine(title: "User", value: process.user.isEmpty ? "Unknown" : process.user)
                        MetadataLine(title: "Executable", value: process.executablePath ?? "Unknown")
                        MetadataLine(title: "Arguments", value: process.arguments ?? "Unknown", lineLimit: 3)
                    }
                    .padding(9)
                    .background(AppTheme.elevatedFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(AppTheme.panelStroke))
                }
            }
        }
    }

    private func connectionsSection(_ port: MonitoredPort) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Connections")
                .font(.callout.weight(.semibold))
                .foregroundStyle(AppTheme.ink)

            VStack(spacing: 0) {
                ConnectionHeader()

                let connections = port.processes.flatMap(\.connections)
                if connections.isEmpty {
                    Text("No active listener for this port.")
                        .font(.callout)
                        .foregroundStyle(AppTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                } else {
                    ForEach(connections) { connection in
                        ConnectionRow(connection: connection)
                        if connection.id != connections.last?.id {
                            Divider()
                                .overlay(AppTheme.panelStroke)
                        }
                    }
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(AppTheme.elevatedFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(AppTheme.panelStroke))
        }
    }

    private func statusTint(_ port: MonitoredPort) -> Color {
        if port.isOccupied {
            return AppTheme.cyan
        }

        if port.isReserved {
            return port.primaryRegistration?.isStale == true ? AppTheme.amber : AppTheme.blue
        }

        return AppTheme.mint
    }

    private func copyReport(_ port: MonitoredPort) {
        let processLines = port.processes.map { process in
            "- \(process.command) PID \(process.pid) \(process.executablePath ?? "")"
        }.joined(separator: "\n")

        let registrationLines = port.registrations.map { registration in
            "- \(registration.tool) \(registration.projectPath) \(registration.command ?? "")"
        }.joined(separator: "\n")

        let text = """
        Port: \(port.port)
        Status: \(port.statusTitle)
        Owner: \(port.ownerSummary)

        Processes:
        \(processLines.isEmpty ? "None" : processLines)

        AI Usage:
        \(registrationLines.isEmpty ? "None" : registrationLines)
        """

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func copyKillCommand(_ port: MonitoredPort) {
        guard let process = port.primaryProcess else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("kill \(process.pid)", forType: .string)
    }

    private func openProject(_ port: MonitoredPort) {
        guard let projectPath = port.primaryRegistration?.projectPath else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: projectPath))
    }
}

struct PortInspectorTitle: View {
    var port: MonitoredPort

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Port Inspector")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)

                Text(port.isOccupied ? "Local listener found" : (port.isReserved ? "Reserved by AI usage" : "Available for local development"))
                    .font(.caption)
                    .foregroundStyle(AppTheme.faint)
            }

            Spacer()
        }
    }
}

struct BulkSelectionBar: View {
    @ObservedObject var viewModel: PortMonitorViewModel

    var body: some View {
        HStack(spacing: 7) {
            Label("\(viewModel.selectedProcesses.count) selected for actions", systemImage: "checkmark.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.ink)

            Spacer()

            Button("Clear") {
                viewModel.clearSelection()
            }
            .buttonStyle(AppButtonStyle(isCompact: true))

            Button("Terminate") {
                viewModel.terminateSelected(force: false)
            }
            .buttonStyle(AppButtonStyle(isCompact: true))

            Button("Force Kill") {
                viewModel.terminateSelected(force: true)
            }
            .buttonStyle(AppButtonStyle(isCompact: true))
            .foregroundStyle(AppTheme.danger)
        }
        .padding(8)
        .background(AppTheme.selectedFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(AppTheme.cyan.opacity(0.22)))
    }
}

struct IconActionButton: View {
    var systemImage: String
    var help: String
    var tint: Color = AppTheme.ink
    var isDisabled = false
    var isCompact = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: isCompact ? 11 : 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: isCompact ? 24 : 28, height: isCompact ? 24 : 28)
                .background(AppTheme.elevatedFill, in: RoundedRectangle(cornerRadius: isCompact ? 7 : 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: isCompact ? 7 : 8, style: .continuous)
                        .strokeBorder(AppTheme.panelStroke)
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.35 : 1)
        .help(help)
    }
}

struct MetricChip: View {
    var title: String
    var value: String
    var tint: Color
    var isCompact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: isCompact ? 8 : 9, weight: .bold))
                .foregroundStyle(AppTheme.faint)

            Text(value)
                .font(isCompact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
        }
        .padding(.horizontal, isCompact ? 7 : 8)
        .padding(.vertical, isCompact ? 5 : 6)
        .frame(maxWidth: isCompact ? nil : .infinity, alignment: .leading)
        .background(AppTheme.elevatedFill, in: RoundedRectangle(cornerRadius: isCompact ? 7 : 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: isCompact ? 7 : 8, style: .continuous).strokeBorder(tint.opacity(0.32)))
    }
}

struct MetadataLine: View {
    var title: String
    var value: String
    var lineLimit = 2

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 0) {
            GridRow {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.faint)
                    .frame(width: 74, alignment: .leading)

                Text(value)
                    .font(.caption.monospaced())
                    .foregroundStyle(AppTheme.ink)
                    .textSelection(.enabled)
                    .lineLimit(lineLimit)
            }
        }
    }
}

struct ConnectionHeader: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("Proto")
                .frame(width: 44, alignment: .leading)
            Text("State")
                .frame(width: 78, alignment: .leading)
            Text("Endpoint")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 9, weight: .bold))
        .foregroundStyle(AppTheme.faint)
        .textCase(.uppercase)
        .padding(.top, 3)
        .padding(.bottom, 4)
    }
}

struct ConnectionRow: View {
    var connection: PortConnection
    var isCompact = false

    var body: some View {
        HStack(spacing: 8) {
            Text(connection.protocolName)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.cyan)
                .frame(width: isCompact ? 34 : 44, alignment: .leading)

            Text(connection.displayState)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(stateColor)
                .frame(width: isCompact ? 70 : 78, alignment: .leading)

            Text(connection.name)
                .font(.caption.monospaced())
                .foregroundStyle(AppTheme.muted)
                .lineLimit(1)
                .textSelection(.enabled)

            Spacer(minLength: 0)
        }
        .padding(.vertical, isCompact ? 5 : 6)
    }

    private var stateColor: Color {
        switch connection.displayState {
        case "LISTEN":
            return AppTheme.mint
        case "ESTABLISHED":
            return AppTheme.cyan
        case "CLOSE_WAIT":
            return AppTheme.amber
        default:
            return AppTheme.faint
        }
    }
}
