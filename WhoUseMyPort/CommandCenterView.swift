import AppKit
import SwiftUI

struct CommandCenter: View {
    @ObservedObject var viewModel: PortMonitorViewModel
    @Binding var appearancePreference: AppAppearancePreference

    private var occupiedCount: Int {
        viewModel.ports.filter(\.isOccupied).count
    }

    private var reservedCount: Int {
        viewModel.ports.filter { $0.isReserved && !$0.isOccupied }.count
    }

    var body: some View {
        VStack(spacing: 7) {
            HStack(alignment: .center, spacing: 10) {
                AppIdentity()
                    .frame(width: 172, alignment: .leading)

                SearchCommand(viewModel: viewModel)
                    .frame(minWidth: 260, maxWidth: .infinity)

                ToolbarActionButton(
                    systemImage: "arrow.clockwise",
                    title: viewModel.isScanning ? "Scanning" : "Scan",
                    help: "Run an immediate scan. The list also refreshes automatically.",
                    isProminent: true,
                    isDisabled: viewModel.isScanning
                ) {
                    viewModel.scan()
                }

                AppearancePicker(appearancePreference: $appearancePreference)
            }
            .frame(maxWidth: .infinity)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    SummaryPillGroup(
                        ports: viewModel.ports.count,
                        occupied: occupiedCount,
                        reserved: reservedCount
                    )

                    Divider()
                        .frame(height: 22)

                    ToolbarActionGroup(viewModel: viewModel)

                    Divider()
                        .frame(height: 22)

                    PresetRail(viewModel: viewModel, showsLabel: true)

                    Spacer(minLength: 0)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        SummaryPillGroup(
                            ports: viewModel.ports.count,
                            occupied: occupiedCount,
                            reserved: reservedCount
                        )
                        ToolbarActionGroup(viewModel: viewModel)
                        PresetRail(viewModel: viewModel, showsLabel: true)
                    }
                    .padding(.bottom, 1)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .surfacePanel(cornerRadius: 12)
    }
}

struct AppearancePicker: View {
    @Binding var appearancePreference: AppAppearancePreference

    var body: some View {
        Picker("Appearance", selection: $appearancePreference) {
            ForEach(AppAppearancePreference.allCases) { preference in
                Text(preference.title).tag(preference)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.small)
        .frame(width: 132)
        .help("Change the app appearance.")
    }
}

struct AppIdentity: View {
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(AppTheme.elevatedFill)

                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.cyan)
            }
            .frame(width: 32, height: 32)
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(AppTheme.panelStroke))

            VStack(alignment: .leading, spacing: 2) {
                Text("Who Use My Port")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)

                Text("Local port conflicts")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.faint)
                    .lineLimit(1)
            }
        }
    }
}

struct SearchCommand: View {
    @ObservedObject var viewModel: PortMonitorViewModel

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.faint)

            TextField("Port, range, or list", text: $viewModel.queryText)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .onSubmit {
                    viewModel.scan()
                }

            ViewThatFits(in: .horizontal) {
                Text("3000, 3000-3010")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AppTheme.faint)

                EmptyView()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(minHeight: 34)
        .background(AppTheme.elevatedFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(AppTheme.panelStroke))
        .help("Enter one port, a range, or a comma-separated list. Press Return to scan.")
    }
}

struct PresetRail: View {
    @ObservedObject var viewModel: PortMonitorViewModel
    var showsLabel = true

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 5) {
                if showsLabel {
                    presetLabel
                }

                ForEach(PortPreset.defaults) { preset in
                    presetButton(preset, width: nil)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    if showsLabel {
                        presetLabel
                    }

                    ForEach(PortPreset.defaults) { preset in
                        presetButton(preset, width: 112)
                    }
                }
            }
        }
    }

    private var presetLabel: some View {
        Label("Presets", systemImage: "line.3.horizontal.decrease.circle")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(AppTheme.faint)
            .frame(width: 74, alignment: .leading)
    }

    private func presetButton(_ preset: PortPreset, width: CGFloat?) -> some View {
        Button {
            viewModel.applyPreset(preset)
        } label: {
            Label(preset.name, systemImage: preset.systemImage)
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .frame(width: width)
        }
        .buttonStyle(PresetButtonStyle(isCompact: true))
        .help("\(preset.description): \(preset.query)")
    }
}

struct SummaryPillGroup: View {
    var ports: Int
    var occupied: Int
    var reserved: Int

    var body: some View {
        HStack(spacing: 6) {
            SummaryPill(title: "Ports", value: "\(ports)", tint: AppTheme.blue)
                .help("Ports currently included in the active query.")
            SummaryPill(title: "Occupied", value: "\(occupied)", tint: AppTheme.cyan)
                .help("Ports with a local listening process.")
            SummaryPill(title: "Reserved", value: "\(reserved)", tint: AppTheme.mint)
                .help("Ports registered by AI usage without a visible listener.")
        }
    }
}

struct SummaryPill: View {
    var title: String
    var value: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(AppTheme.faint)

            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(AppTheme.ink)
        }
        .frame(minWidth: 48, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(AppTheme.elevatedFill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(tint.opacity(0.30)))
    }
}

struct ToolbarActionGroup: View {
    @ObservedObject var viewModel: PortMonitorViewModel

    var body: some View {
        HStack(spacing: 4) {
            ToolbarActionButton(systemImage: "sparkles", help: "Focus the newest AI usage registration.", isDisabled: viewModel.aiRegistrations.isEmpty) {
                guard let registration = viewModel.aiRegistrations.first else { return }
                viewModel.inspect(registration: registration)
            }

            ToolbarActionButton(systemImage: "doc.on.doc", help: "Copy a report for the selected port.", isDisabled: viewModel.selectedPort == nil) {
                copyReport()
            }

            ToolbarActionButton(systemImage: "terminal", help: "Copy the lsof command for the current query.") {
                copyLsofCommand()
            }

            ToolbarActionButton(systemImage: "folder", help: "Open the registered project folder.", isDisabled: viewModel.selectedPort?.primaryRegistration == nil) {
                openProject()
            }

            ToolbarActionButton(systemImage: "xmark.circle", help: "Terminate selected processes.", tint: AppTheme.danger, isDisabled: viewModel.selectedProcesses.isEmpty) {
                viewModel.terminateSelected(force: false)
            }

            ToolbarActionButton(systemImage: "exclamationmark.triangle", help: "Force kill selected processes.", tint: AppTheme.amber, isDisabled: viewModel.selectedProcesses.isEmpty) {
                viewModel.terminateSelected(force: true)
            }
        }
    }

    private func copyReport() {
        guard let port = viewModel.selectedPort else { return }
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

    private func copyLsofCommand() {
        let text: String
        if let query = try? PortQuery.parse(viewModel.queryText) {
            text = query.lsofSpecs
                .map { "lsof -nP -iTCP:\($0) -sTCP:LISTEN" }
                .joined(separator: "\n")
        } else {
            text = "lsof -nP -iTCP:<port> -sTCP:LISTEN"
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func openProject() {
        guard let projectPath = viewModel.selectedPort?.primaryRegistration?.projectPath else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: projectPath))
    }
}

struct ToolbarActionButton: View {
    var systemImage: String
    var title: String?
    var help: String
    var tint: Color = AppTheme.ink
    var isProminent = false
    var isDisabled = false
    var action: () -> Void

    init(
        systemImage: String,
        title: String? = nil,
        help: String,
        tint: Color = AppTheme.ink,
        isProminent: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.title = title
        self.help = help
        self.tint = tint
        self.isProminent = isProminent
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))

                if let title {
                    Text(title)
                        .font(.caption.weight(.semibold))
                }
            }
            .foregroundStyle(isProminent ? Color.white : tint)
            .frame(height: 28)
            .padding(.horizontal, title == nil ? 7 : 9)
            .background(isProminent ? AppTheme.cyan : AppTheme.elevatedFill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(isProminent ? Color.primary.opacity(0.08) : AppTheme.panelStroke))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.35 : 1)
        .help(help)
    }
}

struct QueryBar: View {
    @ObservedObject var viewModel: PortMonitorViewModel
    var isCompact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 7 : 10) {
            HStack(spacing: 11) {
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(AppTheme.cyan)
                        .font(.system(size: isCompact ? 13 : 16, weight: .semibold))

                    TextField("Port or range", text: $viewModel.queryText)
                        .textFieldStyle(.plain)
                        .font(isCompact ? .callout : .title3.monospacedDigit().weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                        .onSubmit {
                            viewModel.scan()
                        }

                    if !isCompact {
                        Text("e.g. 3000, 3000-3010")
                            .font(.caption)
                            .foregroundStyle(AppTheme.faint)
                    }
                }
                .padding(.horizontal, isCompact ? 0 : 12)
                .padding(.vertical, isCompact ? 0 : 9)
                .background {
                    if !isCompact {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(AppTheme.elevatedFill)
                    }
                }
                .overlay {
                    if !isCompact {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(AppTheme.panelStroke)
                    }
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
                .buttonStyle(AppButtonStyle(prominent: true, isCompact: isCompact))
                .controlSize(isCompact ? .small : .regular)
                .disabled(viewModel.isScanning)
                .help("Run an immediate scan.")
            }

            PresetStrip(viewModel: viewModel, isCompact: isCompact)
        }
        .padding(.horizontal, isCompact ? 10 : 14)
        .padding(.vertical, isCompact ? 8 : 11)
        .surfacePanel(cornerRadius: isCompact ? 12 : 12)
    }
}

struct AppButtonStyle: ButtonStyle {
    var prominent = false
    var isCompact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(prominent ? Color.white : AppTheme.ink)
            .padding(.horizontal, isCompact ? 7 : (prominent ? 10 : 7))
            .padding(.vertical, isCompact ? 4 : (prominent ? 6 : 5))
            .background(
                RoundedRectangle(cornerRadius: isCompact ? 7 : 8, style: .continuous)
                    .fill(prominent ? AppTheme.cyan : AppTheme.panelFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: isCompact ? 7 : 8, style: .continuous)
                    .strokeBorder(prominent ? Color.primary.opacity(0.08) : AppTheme.panelStroke)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.snappy(duration: 0.16), value: configuration.isPressed)
    }
}

struct PresetStrip: View {
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

struct PresetButtonStyle: ButtonStyle {
    var isCompact: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: isCompact ? 10 : 11, weight: .semibold))
            .foregroundStyle(AppTheme.ink)
            .padding(.horizontal, isCompact ? 6 : 8)
            .padding(.vertical, isCompact ? 5 : 6)
            .background(
                RoundedRectangle(cornerRadius: isCompact ? 7 : 8, style: .continuous)
                    .fill(configuration.isPressed ? AppTheme.selectedFill : AppTheme.panelFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: isCompact ? 7 : 8, style: .continuous)
                    .strokeBorder(configuration.isPressed ? AppTheme.cyan.opacity(0.22) : AppTheme.panelStroke)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
