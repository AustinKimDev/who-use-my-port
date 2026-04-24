import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: PortMonitorViewModel
    var isCompact: Bool

    var body: some View {
        ZStack {
            PrismBackdrop()

            content
                .padding(.horizontal, isCompact ? 8 : 18)
                .padding(.top, isCompact ? 8 : 34)
                .padding(.bottom, isCompact ? 8 : 18)
        }
        .background(TransparentWindowConfigurator(isResizable: isCompact))
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

                HSplitView {
                    ProcessList(viewModel: viewModel)
                        .frame(minWidth: 280, idealWidth: 360, maxWidth: 520)

                    DetailPanel(viewModel: viewModel)
                        .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                StatusBar(viewModel: viewModel)
            }
        }
    }
}

private struct TransparentWindowConfigurator: NSViewRepresentable {
    var isResizable = false

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
        window.isMovableByWindowBackground = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)

        if isResizable {
            window.styleMask.insert(.resizable)
            window.minSize = NSSize(width: 340, height: 260)
        }
    }
}

private enum PrismTheme {
    static let ink = Color.primary
    static let muted = Color.secondary
    static let faint = Color.secondary.opacity(0.62)
    static let cyan = Color.accentColor
    static let violet = Color.accentColor.opacity(0.78)
    static let mint = Color.green.opacity(0.82)
    static let amber = Color.orange.opacity(0.86)
    static let danger = Color.red.opacity(0.86)
    static let panelStroke = Color.primary.opacity(0.10)
    static let panelFill = Color(nsColor: .controlBackgroundColor).opacity(0.34)
    static let selectedFill = Color.accentColor.opacity(0.14)
}

private struct PrismBackdrop: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)

            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor).opacity(0.22),
                    Color(nsColor: .underPageBackgroundColor).opacity(0.16),
                    Color(nsColor: .controlBackgroundColor).opacity(0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
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
                    .fill(PrismTheme.panelFill.opacity(fillOpacity * 5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(PrismTheme.panelStroke.opacity(strokeOpacity * 5))
            )
            .shadow(color: Color.black.opacity(0.10), radius: 12, y: 7)
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
        VStack(spacing: isCompact ? 7 : 10) {
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
                .buttonStyle(PrismButtonStyle(prominent: true, isCompact: isCompact))
                .controlSize(isCompact ? .small : .regular)
                .disabled(viewModel.isScanning)
            }

            PresetStrip(viewModel: viewModel, isCompact: isCompact)
        }
        .padding(.horizontal, isCompact ? 10 : 14)
        .padding(.vertical, isCompact ? 8 : 11)
        .glassPanel(cornerRadius: isCompact ? 16 : 22, fillOpacity: 0.10)
    }
}

private struct PrismButtonStyle: ButtonStyle {
    var prominent = false
    var isCompact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isCompact ? .caption.weight(.semibold) : .callout.weight(.semibold))
            .foregroundStyle(prominent ? Color(red: 0.04, green: 0.07, blue: 0.11) : PrismTheme.ink)
            .padding(.horizontal, isCompact ? 8 : (prominent ? 12 : 8))
            .padding(.vertical, isCompact ? 5 : (prominent ? 7 : 6))
            .background(
                RoundedRectangle(cornerRadius: isCompact ? 9 : 11, style: .continuous)
                    .fill(prominent ? PrismTheme.cyan.opacity(0.88) : PrismTheme.panelFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: isCompact ? 9 : 11, style: .continuous)
                    .strokeBorder(prominent ? Color.primary.opacity(0.08) : PrismTheme.panelStroke)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.snappy(duration: 0.16), value: configuration.isPressed)
    }
}

private struct PresetStrip: View {
    @ObservedObject var viewModel: PortMonitorViewModel
    var isCompact: Bool

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: isCompact ? 3 : 6)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(PortPreset.defaults) { preset in
                Button {
                    viewModel.applyPreset(preset)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: preset.systemImage)
                            .font(.system(size: isCompact ? 9 : 10, weight: .semibold))

                        Text(preset.name)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PresetButtonStyle(isCompact: isCompact))
                .help("\(preset.description): \(preset.query)")
            }
        }
    }
}

private struct PresetButtonStyle: ButtonStyle {
    var isCompact: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: isCompact ? 10 : 11, weight: .semibold))
            .foregroundStyle(PrismTheme.ink)
            .padding(.horizontal, isCompact ? 6 : 8)
            .padding(.vertical, isCompact ? 5 : 6)
            .background(
                RoundedRectangle(cornerRadius: isCompact ? 8 : 10, style: .continuous)
                    .fill(configuration.isPressed ? PrismTheme.selectedFill : PrismTheme.panelFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: isCompact ? 8 : 10, style: .continuous)
                    .strokeBorder(configuration.isPressed ? PrismTheme.cyan.opacity(0.22) : PrismTheme.panelStroke)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct CompactMenuBarView: View {
    @ObservedObject var viewModel: PortMonitorViewModel

    var body: some View {
        VStack(spacing: 7) {
            MenuBarCommandRow(viewModel: viewModel)

            MenuBarPresetRow(viewModel: viewModel)

            Divider()
                .overlay(PrismTheme.panelStroke)

            CompactProcessList(viewModel: viewModel, isMenuBar: true)
                .frame(minHeight: 130, maxHeight: .infinity)

            MenuBarSelectionFooter(viewModel: viewModel)
        }
    }
}

private struct MenuBarCommandRow: View {
    @ObservedObject var viewModel: PortMonitorViewModel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "network")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PrismTheme.cyan)

            TextField("Port or range", text: $viewModel.queryText)
                .textFieldStyle(.plain)
                .font(.callout.monospacedDigit().weight(.semibold))
                .onSubmit {
                    viewModel.scan()
                }

            Circle()
                .fill(viewModel.errorMessage == nil ? PrismTheme.mint : PrismTheme.danger)
                .frame(width: 6, height: 6)

            Text(statusLabel)
                .font(.caption2.monospacedDigit().weight(.medium))
                .foregroundStyle(viewModel.errorMessage == nil ? PrismTheme.faint : PrismTheme.danger)
                .lineLimit(1)
                .frame(maxWidth: 82, alignment: .trailing)

            Button {
                viewModel.scan()
            } label: {
                if viewModel.isScanning {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(PrismButtonStyle(prominent: true, isCompact: true))
            .disabled(viewModel.isScanning)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(PrismTheme.panelStroke))
    }

    private var statusLabel: String {
        if let errorMessage = viewModel.errorMessage {
            return errorMessage
        }

        if viewModel.processes.isEmpty {
            return "0 found"
        }

        if viewModel.selectedPIDs.isEmpty {
            return "\(viewModel.processes.count) found"
        }

        return "\(viewModel.selectedPIDs.count)/\(viewModel.processes.count)"
    }
}

private struct MenuBarPresetRow: View {
    @ObservedObject var viewModel: PortMonitorViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(PortPreset.defaults) { preset in
                    Button {
                        viewModel.applyPreset(preset)
                    } label: {
                        Label(preset.name, systemImage: preset.systemImage)
                            .labelStyle(.titleAndIcon)
                            .lineLimit(1)
                    }
                    .buttonStyle(PresetButtonStyle(isCompact: true))
                    .help("\(preset.description): \(preset.query)")
                }
            }
            .padding(.horizontal, 1)
            .padding(.vertical, 1)
        }
    }
}

private struct MenuBarSelectionFooter: View {
    @ObservedObject var viewModel: PortMonitorViewModel

    var body: some View {
        HStack(spacing: 8) {
            if let process = viewModel.selectedProcess {
                VStack(alignment: .leading, spacing: 1) {
                    Text(process.command)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)

                    Text("\(viewModel.selectedProcesses.count) selected | PID \(process.pid)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(PrismTheme.faint)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                GlassIconButton(systemImage: "doc.on.doc", help: "Copy", isCompact: true) {
                    copyDetails(process)
                }

                GlassIconButton(systemImage: "xmark.circle", help: "Terminate selected", tint: PrismTheme.danger, isCompact: true) {
                    viewModel.terminateSelected(force: false)
                }

                GlassIconButton(systemImage: "exclamationmark.triangle", help: "Force kill selected", tint: PrismTheme.amber, isCompact: true) {
                    viewModel.terminateSelected(force: true)
                }
            } else {
                Text(viewModel.errorMessage ?? viewModel.statusText)
                    .font(.caption)
                    .foregroundStyle(viewModel.errorMessage == nil ? PrismTheme.muted : PrismTheme.danger)
                    .lineLimit(1)

                Spacer()
            }
        }
        .frame(minHeight: 30)
        .padding(.horizontal, 2)
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

                if !viewModel.selectedPIDs.isEmpty {
                    Text("\(viewModel.selectedPIDs.count) selected")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(PrismTheme.cyan)
                }
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
    var isMenuBar = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                if viewModel.processes.isEmpty, !viewModel.isScanning {
                    NativeEmptyState(
                        title: "No processes",
                        systemImage: "network.slash",
                        message: "Try another port or preset."
                    )
                    .frame(maxWidth: .infinity, minHeight: isMenuBar ? 96 : 180)
                } else {
                    ForEach(viewModel.processes) { process in
                        CompactProcessRow(
                            process: process,
                            isSelected: viewModel.selectedPIDs.contains(process.pid),
                            isMenuBar: isMenuBar
                        ) {
                            viewModel.toggleSelection(
                                pid: process.pid,
                                extendRange: NSEvent.modifierFlags.contains(.shift)
                            )
                        }
                    }
                }
            }
            .padding(isMenuBar ? 2 : 10)
        }
    }
}

private struct CompactProcessRow: View {
    var process: PortProcess
    var isSelected: Bool
    var isMenuBar = false
    var select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: isMenuBar ? 7 : 10) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PrismTheme.cyan)
                }

                VStack(alignment: .leading, spacing: isMenuBar ? 2 : 4) {
                    Text(process.command)
                        .font(isMenuBar ? .caption.weight(.semibold) : .callout.weight(.semibold))
                        .foregroundStyle(PrismTheme.ink)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(isMenuBar ? process.portSummary : "Ports \(process.portSummary)")
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
            .padding(.horizontal, isMenuBar ? 7 : 10)
            .padding(.vertical, isMenuBar ? 6 : 9)
            .contentShape(Rectangle())
            .background {
                if isMenuBar || isSelected {
                    rowBackground
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: isMenuBar ? 9 : 14, style: .continuous)
                    .strokeBorder(isSelected ? PrismTheme.cyan.opacity(0.34) : PrismTheme.panelStroke)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(process.command), PID \(process.pid), ports \(process.portSummary)")
        .accessibilityHint("Click to toggle selection. Shift click selects a range.")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: isMenuBar ? 9 : 14, style: .continuous)
            .fill(
                isSelected
                ? LinearGradient(
                    colors: [PrismTheme.cyan.opacity(0.14), PrismTheme.cyan.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                : LinearGradient(
                    colors: [PrismTheme.panelFill, PrismTheme.panelFill.opacity(0.70)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}

private struct NativeEmptyState: View {
    var title: String
    var systemImage: String
    var message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(PrismTheme.faint)

            Text(title)
                .font(.headline)
                .foregroundStyle(PrismTheme.ink)

            Text(message)
                .font(.callout)
                .foregroundStyle(PrismTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
    }
}

private struct DetailPanel: View {
    @ObservedObject var viewModel: PortMonitorViewModel

    var body: some View {
        Group {
            if let process = viewModel.selectedProcess {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if viewModel.selectedProcesses.count > 1 {
                            BulkSelectionBar(viewModel: viewModel)
                        }

                        detailHeader(process)
                        metricChips(process)
                        processMetadata(process)
                        connectionsList(process)
                    }
                    .padding(16)
                }
            } else {
                NativeEmptyState(
                    title: "Select a process",
                    systemImage: "info.circle",
                    message: "Choose a result to inspect ports, PID, and launch arguments."
                )
                .padding(18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassPanel(cornerRadius: 24, fillOpacity: 0.07)
    }

    private func detailHeader(_ process: PortProcess) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(process.command)
                    .font(.title2.weight(.semibold))
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
        .background(PrismTheme.panelFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(PrismTheme.panelStroke))
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
                            .overlay(PrismTheme.panelStroke)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(PrismTheme.panelFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(PrismTheme.panelStroke))
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

private struct BulkSelectionBar: View {
    @ObservedObject var viewModel: PortMonitorViewModel

    var body: some View {
        HStack(spacing: 10) {
            Label("\(viewModel.selectedProcesses.count) selected", systemImage: "checkmark.circle")
                .font(.callout.weight(.semibold))
                .foregroundStyle(PrismTheme.ink)

            Spacer()

            Button("Clear") {
                viewModel.clearSelection()
            }
            .buttonStyle(PrismButtonStyle(isCompact: true))

            Button("Terminate") {
                viewModel.terminateSelected(force: false)
            }
            .buttonStyle(PrismButtonStyle(isCompact: true))

            Button("Force Kill") {
                viewModel.terminateSelected(force: true)
            }
            .buttonStyle(PrismButtonStyle(isCompact: true))
            .foregroundStyle(PrismTheme.danger)
        }
        .padding(10)
        .background(PrismTheme.selectedFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(PrismTheme.cyan.opacity(0.22)))
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
                    if viewModel.selectedProcesses.count > 1 {
                        MetricChip(title: "Selected", value: "\(viewModel.selectedProcesses.count)", tint: PrismTheme.cyan, isCompact: true)
                    }
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
                NativeEmptyState(
                    title: "Select",
                    systemImage: "info.circle",
                    message: "Pick a process."
                )
                .font(.caption)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        .background(PrismTheme.panelFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                .background(PrismTheme.panelFill, in: RoundedRectangle(cornerRadius: isCompact ? 8 : 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: isCompact ? 8 : 10, style: .continuous)
                        .strokeBorder(PrismTheme.panelStroke)
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
