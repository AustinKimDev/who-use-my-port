import AppKit
import SwiftUI

struct CompactMenuBarView: View {
    @ObservedObject var viewModel: PortMonitorViewModel
    @State private var mode: SidebarListMode = .ports

    var body: some View {
        VStack(spacing: 6) {
            MenuBarCommandRow(viewModel: viewModel)

            HStack(spacing: 6) {
                Picker("List", selection: $mode) {
                    ForEach(SidebarListMode.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .help("Switch between scanned ports and AI usage.")

                ToolbarActionButton(systemImage: "sparkles", help: "Inspect newest AI usage.", isDisabled: viewModel.aiRegistrations.isEmpty) {
                    guard let registration = viewModel.aiRegistrations.first else { return }
                    viewModel.inspect(registration: registration)
                    mode = .aiUsage
                }
            }

            MenuBarPresetRow(viewModel: viewModel)

            Group {
                switch mode {
                case .ports:
                    PortList(viewModel: viewModel, isMenuBar: true)
                case .aiUsage:
                    AIUsageList(viewModel: viewModel)
                }
            }
            .frame(minHeight: 130, maxHeight: .infinity)

            MenuBarSelectionFooter(viewModel: viewModel)
        }
    }
}

struct MenuBarCommandRow: View {
    @ObservedObject var viewModel: PortMonitorViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "network")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.cyan)

            TextField("Port or range", text: $viewModel.queryText)
                .textFieldStyle(.plain)
                .font(.caption.monospacedDigit().weight(.semibold))
                .onSubmit {
                    viewModel.scan()
                }

            Circle()
                .fill(viewModel.errorMessage == nil ? AppTheme.mint : AppTheme.danger)
                .frame(width: 6, height: 6)

            Text(statusLabel)
                .font(.caption2.monospacedDigit().weight(.medium))
                .foregroundStyle(viewModel.errorMessage == nil ? AppTheme.faint : AppTheme.danger)
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
            .buttonStyle(AppButtonStyle(prominent: true, isCompact: true))
            .disabled(viewModel.isScanning)
            .help("Run an immediate scan.")

            Button {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Image(systemName: "macwindow")
            }
            .buttonStyle(AppButtonStyle(isCompact: true))
            .help("Open the main window.")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(AppTheme.panelFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(AppTheme.panelStroke))
    }

    private var statusLabel: String {
        if let errorMessage = viewModel.errorMessage {
            return errorMessage
        }

        if viewModel.ports.isEmpty {
            return "0 found"
        }

        if viewModel.selectedPIDs.isEmpty {
            return "\(viewModel.ports.count) ports"
        }

        return "\(viewModel.selectedPIDs.count)/\(viewModel.ports.count)"
    }
}

struct MenuBarPresetRow: View {
    @ObservedObject var viewModel: PortMonitorViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
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

struct MenuBarSelectionFooter: View {
    @ObservedObject var viewModel: PortMonitorViewModel

    var body: some View {
        HStack(spacing: 6) {
            if let process = viewModel.selectedProcess {
                VStack(alignment: .leading, spacing: 1) {
                    Text(process.command)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)

                    Text("\(viewModel.selectedProcesses.count) selected | PID \(process.pid)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(AppTheme.faint)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                IconActionButton(systemImage: "doc.on.doc", help: "Copy", isCompact: true) {
                    copyDetails(process)
                }

                IconActionButton(systemImage: "xmark.circle", help: "Terminate selected", tint: AppTheme.danger, isCompact: true) {
                    viewModel.terminateSelected(force: false)
                }

                IconActionButton(systemImage: "exclamationmark.triangle", help: "Force kill selected", tint: AppTheme.amber, isCompact: true) {
                    viewModel.terminateSelected(force: true)
                }
            } else {
                Text(viewModel.errorMessage ?? viewModel.statusText)
                    .font(.caption)
                    .foregroundStyle(viewModel.errorMessage == nil ? AppTheme.muted : AppTheme.danger)
                    .lineLimit(1)

                Spacer()
            }
        }
        .frame(minHeight: 28)
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
