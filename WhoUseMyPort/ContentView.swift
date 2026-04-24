import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: PortMonitorViewModel
    var isCompact: Bool

    var body: some View {
        ZStack {
            PrismBackdrop()

            content
                .padding(isCompact ? 10 : 18)
        }
        .background(TransparentWindowConfigurator())
        .preferredColorScheme(.dark)
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
            VStack(spacing: 14) {
                QueryBar(viewModel: viewModel, isCompact: false)

                HStack(spacing: 14) {
                    ProcessList(viewModel: viewModel)
                        .frame(minWidth: 320, idealWidth: 360)

                    DetailPanel(viewModel: viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                StatusBar(viewModel: viewModel)
            }
        }
    }
}

private struct TransparentWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: nsView.window)
        }
    }

    private func configure(window: NSWindow?) {
        guard let window else { return }

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
    }
}

private enum PrismTheme {
    static let ink = Color(red: 0.96, green: 0.97, blue: 1.0)
    static let muted = Color(red: 0.70, green: 0.74, blue: 0.82)
    static let faint = Color(red: 0.48, green: 0.53, blue: 0.63)
    static let cyan = Color(red: 0.43, green: 0.82, blue: 0.96)
    static let violet = Color(red: 0.82, green: 0.48, blue: 1.0)
    static let mint = Color(red: 0.42, green: 0.92, blue: 0.70)
    static let amber = Color(red: 1.0, green: 0.68, blue: 0.32)
    static let danger = Color(red: 1.0, green: 0.42, blue: 0.44)
    static let panelStroke = Color.white.opacity(0.15)
    static let panelFill = Color.white.opacity(0.08)
    static let selectedFill = Color(red: 0.52, green: 0.64, blue: 1.0).opacity(0.18)
}

private struct PrismBackdrop: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)

            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.10, blue: 0.17).opacity(0.62),
                    Color(red: 0.13, green: 0.11, blue: 0.22).opacity(0.48),
                    Color(red: 0.08, green: 0.16, blue: 0.20).opacity(0.38)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [PrismTheme.violet.opacity(0.34), .clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 420
            )

            RadialGradient(
                colors: [PrismTheme.cyan.opacity(0.25), .clear],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 500
            )

            RadialGradient(
                colors: [PrismTheme.mint.opacity(0.16), .clear],
                center: .bottomTrailing,
                startRadius: 40,
                endRadius: 460
            )
        }
        .ignoresSafeArea()
    }
}

private struct GlassPanel: ViewModifier {
    var cornerRadius: CGFloat = 20
    var fillOpacity: Double = 0.08
    var strokeOpacity: Double = 0.16

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(fillOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(strokeOpacity + 0.06),
                                PrismTheme.cyan.opacity(strokeOpacity),
                                PrismTheme.violet.opacity(strokeOpacity * 0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: Color.black.opacity(0.28), radius: 24, y: 16)
    }
}

private extension View {
    func glassPanel(cornerRadius: CGFloat = 20, fillOpacity: Double = 0.08, strokeOpacity: Double = 0.16) -> some View {
        modifier(GlassPanel(cornerRadius: cornerRadius, fillOpacity: fillOpacity, strokeOpacity: strokeOpacity))
    }
}

private struct QueryBar: View {
    @ObservedObject var viewModel: PortMonitorViewModel
    var isCompact: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "network")
                .foregroundStyle(PrismTheme.cyan)
                .font(.system(size: isCompact ? 13 : 16, weight: .semibold))

            TextField("Port or range", text: $viewModel.queryText)
                .textFieldStyle(.plain)
                .font(isCompact ? .callout : .title3.weight(.semibold))
                .foregroundStyle(PrismTheme.ink)
                .onSubmit {
                    viewModel.scan()
                }

            if !isCompact {
                Text("3000, 3000-3010")
                    .font(.caption)
                    .foregroundStyle(PrismTheme.faint)
            }

            Button {
                viewModel.scan()
            } label: {
                if isCompact {
                    Image(systemName: "arrow.clockwise")
                } else {
                    Label(viewModel.isScanning ? "Scanning" : "Scan", systemImage: "arrow.clockwise")
                }
            }
            .buttonStyle(PrismButtonStyle(prominent: true))
            .controlSize(isCompact ? .small : .regular)
            .disabled(viewModel.isScanning)
        }
        .padding(.horizontal, isCompact ? 10 : 14)
        .padding(.vertical, isCompact ? 8 : 12)
        .glassPanel(cornerRadius: isCompact ? 16 : 22, fillOpacity: 0.10)
    }
}

private struct PrismButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(prominent ? Color(red: 0.04, green: 0.07, blue: 0.11) : PrismTheme.ink)
            .padding(.horizontal, prominent ? 12 : 8)
            .padding(.vertical, prominent ? 7 : 6)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        prominent
                        ? LinearGradient(colors: [PrismTheme.cyan, PrismTheme.violet.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(Color.white.opacity(prominent ? 0.30 : 0.14))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.snappy(duration: 0.16), value: configuration.isPressed)
    }
}

private struct CompactMenuBarView: View {
    @ObservedObject var viewModel: PortMonitorViewModel

    var body: some View {
        VStack(spacing: 10) {
            QueryBar(viewModel: viewModel, isCompact: true)
            CompactStatus(viewModel: viewModel)

            CompactProcessList(viewModel: viewModel)
                .frame(height: 216)
                .glassPanel(cornerRadius: 18, fillOpacity: 0.07)

            CompactProcessInspector(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .glassPanel(cornerRadius: 18, fillOpacity: 0.07)
        }
    }
}

private struct CompactStatus: View {
    @ObservedObject var viewModel: PortMonitorViewModel

    var body: some View {
        HStack(spacing: 7) {
            if viewModel.isScanning {
                ProgressView()
                    .controlSize(.small)
            }

            Circle()
                .fill(viewModel.errorMessage == nil ? PrismTheme.mint : PrismTheme.danger)
                .frame(width: 7, height: 7)
                .shadow(color: (viewModel.errorMessage == nil ? PrismTheme.mint : PrismTheme.danger).opacity(0.8), radius: 5)

            Text(viewModel.errorMessage ?? viewModel.statusText)
                .font(.caption2.weight(.medium))
                .foregroundStyle(viewModel.errorMessage == nil ? PrismTheme.muted : PrismTheme.danger)
                .lineLimit(1)

            Spacer()

            Text("\(viewModel.processes.count)")
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(PrismTheme.ink)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(PrismTheme.panelFill, in: Capsule())
        }
        .padding(.horizontal, 4)
    }
}

private struct ProcessList: View {
    @ObservedObject var viewModel: PortMonitorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Processes", systemImage: "cpu")
                    .font(.headline)
                    .foregroundStyle(PrismTheme.ink)

                Spacer()

                Text("\(viewModel.processes.count)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(PrismTheme.muted)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)

            CompactProcessList(viewModel: viewModel)
        }
        .glassPanel(cornerRadius: 24, fillOpacity: 0.075)
    }
}

private struct CompactProcessList: View {
    @ObservedObject var viewModel: PortMonitorViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                if viewModel.processes.isEmpty, !viewModel.isScanning {
                    ContentUnavailableView(
                        "No Processes",
                        systemImage: "network.slash",
                        description: Text("Try another port or range.")
                    )
                    .foregroundStyle(PrismTheme.muted)
                    .padding(.top, 40)
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
            .padding(10)
        }
    }
}

private struct CompactProcessRow: View {
    var process: PortProcess
    var isSelected: Bool
    var select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(process.command)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(PrismTheme.ink)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text("Ports \(process.portSummary)")
                        Text("PID \(process.pid)")
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(PrismTheme.muted)
                    .lineLimit(1)
                }

                Spacer(minLength: 6)

                Text(process.protocolsSummary)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isSelected ? PrismTheme.cyan : PrismTheme.faint)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
            .background(rowBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? PrismTheme.cyan.opacity(0.34) : Color.white.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                isSelected
                ? LinearGradient(
                    colors: [PrismTheme.violet.opacity(0.23), PrismTheme.cyan.opacity(0.16)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                : LinearGradient(
                    colors: [Color.white.opacity(0.07), Color.white.opacity(0.03)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}

private struct DetailPanel: View {
    @ObservedObject var viewModel: PortMonitorViewModel

    var body: some View {
        Group {
            if let process = viewModel.selectedProcess {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        detailHeader(process)
                        metricChips(process)
                        processMetadata(process)
                        connectionsList(process)
                    }
                    .padding(16)
                }
            } else {
                ContentUnavailableView(
                    "Select a Process",
                    systemImage: "info.circle",
                    description: Text("Choose a result to inspect process details.")
                )
                .foregroundStyle(PrismTheme.muted)
            }
        }
        .glassPanel(cornerRadius: 24, fillOpacity: 0.07)
    }

    private func detailHeader(_ process: PortProcess) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(process.command)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(PrismTheme.ink)
                    .lineLimit(1)

                Text("PID \(process.pid) | \(process.user.isEmpty ? "Unknown user" : process.user)")
                    .font(.callout)
                    .foregroundStyle(PrismTheme.muted)
            }

            Spacer()

            actionButtons(process)
        }
    }

    private func actionButtons(_ process: PortProcess) -> some View {
        HStack(spacing: 8) {
            GlassIconButton(systemImage: "doc.on.doc", help: "Copy") {
                copyDetails(process)
            }

            GlassIconButton(systemImage: "folder", help: "Reveal", isDisabled: process.executablePath == nil) {
                revealExecutable(process)
            }

            GlassIconButton(systemImage: "xmark.circle", help: "Terminate", tint: PrismTheme.danger) {
                viewModel.terminateSelected(force: false)
            }

            GlassIconButton(systemImage: "exclamationmark.triangle", help: "Force Kill", tint: PrismTheme.amber) {
                viewModel.terminateSelected(force: true)
            }
        }
    }

    private func metricChips(_ process: PortProcess) -> some View {
        HStack(spacing: 8) {
            MetricChip(title: "Ports", value: process.portSummary, tint: PrismTheme.cyan)
            MetricChip(title: "Protocol", value: process.protocolsSummary, tint: PrismTheme.violet)
            MetricChip(title: "Connections", value: "\(process.connections.count)", tint: PrismTheme.mint)
        }
    }

    private func processMetadata(_ process: PortProcess) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            MetadataLine(title: "Executable", value: process.executablePath ?? "Unknown")
            MetadataLine(title: "Arguments", value: process.arguments ?? "Unknown", lineLimit: 3)
        }
        .padding(13)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.10)))
    }

    private func connectionsList(_ process: PortProcess) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Connections")
                .font(.headline)
                .foregroundStyle(PrismTheme.ink)

            VStack(spacing: 0) {
                ForEach(process.connections) { connection in
                    ConnectionRow(connection: connection)
                    if connection.id != process.connections.last?.id {
                        Divider()
                            .overlay(Color.white.opacity(0.08))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.10)))
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

private struct CompactProcessInspector: View {
    @ObservedObject var viewModel: PortMonitorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let process = viewModel.selectedProcess {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(process.command)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(PrismTheme.ink)
                            .lineLimit(1)

                        Text("PID \(process.pid) | \(process.user.isEmpty ? "Unknown" : process.user)")
                            .font(.caption2)
                            .foregroundStyle(PrismTheme.muted)
                            .lineLimit(1)
                    }

                    Spacer()

                    compactActionButtons(process)
                }

                HStack(spacing: 6) {
                    MetricChip(title: "Ports", value: process.portSummary, tint: PrismTheme.cyan, isCompact: true)
                    MetricChip(title: "Conn", value: "\(process.connections.count)", tint: PrismTheme.mint, isCompact: true)
                }

                compactMetadata(process)

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(process.connections) { connection in
                            ConnectionRow(connection: connection, isCompact: true)
                        }
                    }
                }
            } else {
                ContentUnavailableView("Select a Process", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(PrismTheme.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(12)
    }

    private func compactActionButtons(_ process: PortProcess) -> some View {
        HStack(spacing: 5) {
            GlassIconButton(systemImage: "doc.on.doc", help: "Copy", isCompact: true) {
                copyDetails(process)
            }

            GlassIconButton(systemImage: "folder", help: "Reveal", isDisabled: process.executablePath == nil, isCompact: true) {
                revealExecutable(process)
            }

            GlassIconButton(systemImage: "xmark.circle", help: "Terminate", tint: PrismTheme.danger, isCompact: true) {
                viewModel.terminateSelected(force: false)
            }

            GlassIconButton(systemImage: "exclamationmark.triangle", help: "Force Kill", tint: PrismTheme.amber, isCompact: true) {
                viewModel.terminateSelected(force: true)
            }
        }
    }

    private func compactMetadata(_ process: PortProcess) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(process.executablePath ?? "Unknown executable")
                .font(.caption2)
                .foregroundStyle(PrismTheme.muted)
                .lineLimit(1)
                .textSelection(.enabled)

            Text(process.arguments ?? "No arguments")
                .font(.caption2)
                .foregroundStyle(PrismTheme.faint)
                .lineLimit(2)
                .textSelection(.enabled)
        }
        .padding(9)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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

private struct GlassIconButton: View {
    var systemImage: String
    var help: String
    var tint: Color = PrismTheme.ink
    var isDisabled = false
    var isCompact = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: isCompact ? 11 : 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: isCompact ? 26 : 32, height: isCompact ? 26 : 32)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: isCompact ? 9 : 11, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: isCompact ? 9 : 11, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14))
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.35 : 1)
        .help(help)
    }
}

private struct MetricChip: View {
    var title: String
    var value: String
    var tint: Color
    var isCompact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: isCompact ? 8 : 9, weight: .bold))
                .foregroundStyle(PrismTheme.faint)

            Text(value)
                .font(isCompact ? .caption2.weight(.semibold) : .callout.weight(.semibold))
                .foregroundStyle(PrismTheme.ink)
                .lineLimit(1)
        }
        .padding(.horizontal, isCompact ? 8 : 11)
        .padding(.vertical, isCompact ? 6 : 8)
        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: isCompact ? 11 : 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: isCompact ? 11 : 14, style: .continuous).strokeBorder(tint.opacity(0.28)))
    }
}

private struct MetadataLine: View {
    var title: String
    var value: String
    var lineLimit = 2

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 0) {
            GridRow {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PrismTheme.faint)
                    .frame(width: 82, alignment: .leading)

                Text(value)
                    .font(.callout.monospaced())
                    .foregroundStyle(PrismTheme.ink)
                    .textSelection(.enabled)
                    .lineLimit(lineLimit)
            }
        }
    }
}

private struct ConnectionRow: View {
    var connection: PortConnection
    var isCompact = false

    var body: some View {
        HStack(spacing: 8) {
            Text(connection.protocolName)
                .font(.caption2.weight(.bold))
                .foregroundStyle(PrismTheme.cyan)
                .frame(width: isCompact ? 34 : 44, alignment: .leading)

            Text(connection.displayState)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(stateColor)
                .frame(width: isCompact ? 70 : 92, alignment: .leading)

            Text(connection.name)
                .font(.caption.monospaced())
                .foregroundStyle(PrismTheme.muted)
                .lineLimit(1)
                .textSelection(.enabled)

            Spacer(minLength: 0)
        }
        .padding(.vertical, isCompact ? 5 : 8)
    }

    private var stateColor: Color {
        switch connection.displayState {
        case "LISTEN":
            return PrismTheme.mint
        case "ESTABLISHED":
            return PrismTheme.cyan
        case "CLOSE_WAIT":
            return PrismTheme.amber
        default:
            return PrismTheme.faint
        }
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

            Circle()
                .fill(viewModel.errorMessage == nil ? PrismTheme.mint : PrismTheme.danger)
                .frame(width: 7, height: 7)
                .shadow(color: (viewModel.errorMessage == nil ? PrismTheme.mint : PrismTheme.danger).opacity(0.8), radius: 5)

            Text(viewModel.errorMessage ?? viewModel.statusText)
                .font(.caption.weight(.medium))
                .foregroundStyle(viewModel.errorMessage == nil ? PrismTheme.muted : PrismTheme.danger)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .glassPanel(cornerRadius: 16, fillOpacity: 0.06, strokeOpacity: 0.12)
    }
}
