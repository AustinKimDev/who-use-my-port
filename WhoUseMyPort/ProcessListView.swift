import AppKit
import SwiftUI

struct ProcessList: View {
    @ObservedObject var viewModel: PortMonitorViewModel
    @State private var mode: SidebarListMode = .ports

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ResultsHeader(viewModel: viewModel, mode: $mode)

            if mode == .ports, !viewModel.ports.isEmpty {
                PortListHeader()
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }

            Group {
                switch mode {
                case .ports:
                    PortList(viewModel: viewModel)
                case .aiUsage:
                    AIUsageList(viewModel: viewModel)
                }
            }
        }
        .surfacePanel(cornerRadius: 10)
    }
}

enum SidebarListMode: String, CaseIterable, Identifiable {
    case ports
    case aiUsage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ports:
            return "Ports"
        case .aiUsage:
            return "AI Usage"
        }
    }
}

struct ResultsHeader: View {
    @ObservedObject var viewModel: PortMonitorViewModel
    @Binding var mode: SidebarListMode

    private var occupiedCount: Int {
        viewModel.ports.filter(\.isOccupied).count
    }

    private var liveAIUsageCount: Int {
        viewModel.aiRegistrations.filter { !$0.isStale }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Picker("List", selection: $mode) {
                ForEach(SidebarListMode.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .help("Switch between scanned ports and AI-registered services.")

            HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Label(mode.title, systemImage: mode == .ports ? "list.bullet.rectangle" : "sparkles")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)

                Text(summaryText)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.faint)
            }

            Spacer()

            if !viewModel.selectedPIDs.isEmpty {
                Button("Clear") {
                    viewModel.clearSelection()
                }
                .buttonStyle(AppButtonStyle(isCompact: true))
                .help("Clear selected processes.")

                Text("\(viewModel.selectedPIDs.count) selected")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.cyan)
            }
        }
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(AppTheme.panelFill)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var summaryText: String {
        switch mode {
        case .ports:
            return viewModel.ports.isEmpty ? "No matching ports" : "\(occupiedCount) occupied of \(viewModel.ports.count)"
        case .aiUsage:
            return viewModel.aiRegistrations.isEmpty ? "No registrations" : "\(liveAIUsageCount) live of \(viewModel.aiRegistrations.count)"
        }
    }
}

struct PortListHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            Color.clear
                .frame(width: 18)
            Text("Port")
                .frame(width: 42, alignment: .leading)
            Text("Status")
                .frame(width: 76, alignment: .leading)
            Text("Process")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 9, weight: .bold))
        .foregroundStyle(AppTheme.faint)
        .textCase(.uppercase)
    }
}

struct PortList: View {
    @ObservedObject var viewModel: PortMonitorViewModel
    var isMenuBar = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                if viewModel.ports.isEmpty, !viewModel.isScanning {
                    NativeEmptyState(
                        title: "No ports",
                        systemImage: "network.slash",
                        message: "Try another port pack or scan a specific port."
                    )
                    .frame(maxWidth: .infinity, minHeight: isMenuBar ? 96 : 220)
                } else {
                    ForEach(viewModel.ports) { port in
                        PortRow(
                            port: port,
                            isFocused: viewModel.focusedPort == port.port,
                            isSelected: port.primaryProcess.map { viewModel.selectedPIDs.contains($0.pid) } ?? false,
                            isMenuBar: isMenuBar
                        ) {
                            viewModel.focus(port: port.port)
                        } toggleSelection: {
                            guard let pid = port.primaryProcess?.pid else { return }
                            viewModel.toggleSelection(
                                pid: pid,
                                extendRange: NSEvent.modifierFlags.contains(.shift)
                            )
                        }
                    }
                }
            }
            .padding(isMenuBar ? 2 : 6)
        }
    }
}

struct PortRow: View {
    var port: MonitoredPort
    var isFocused: Bool
    var isSelected: Bool
    var isMenuBar = false
    var focus: () -> Void
    var toggleSelection: () -> Void

    var body: some View {
        Button(action: focus) {
            rowContent
                .padding(.horizontal, isMenuBar ? 7 : 8)
                .padding(.vertical, isMenuBar ? 6 : 6)
                .contentShape(Rectangle())
                .background {
                    rowBackground
                }
                .overlay(
                    RoundedRectangle(cornerRadius: isMenuBar ? 7 : 8, style: .continuous)
                        .strokeBorder(rowStroke)
                )
        }
        .buttonStyle(.plain)
        .help(rowHelp)
        .accessibilityLabel("Port \(port.port), \(port.statusTitle), \(port.ownerSummary)")
        .accessibilityHint("Click to inspect this port. Use the check control to select the occupying process for actions.")
        .accessibilityValue(isSelected ? "Selected for actions" : (isFocused ? "Inspecting" : "Not selected"))
    }

    @ViewBuilder
    private var rowContent: some View {
        if isMenuBar {
            HStack(spacing: 7) {
                Text("\(port.port)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 48, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(port.ownerSummary)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)

                    Text(port.processSummary)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                StatusBadge(text: port.statusTitle, tint: statusTint, isCompact: true)
                    .help(statusHelp)
            }
        } else {
            HStack(spacing: 10) {
                Button(action: toggleSelection) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? AppTheme.cyan : AppTheme.faint)
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(port.primaryProcess == nil)
                .opacity(port.primaryProcess == nil ? 0.35 : 1)
                .help(isSelected ? "Remove from selection" : "Select occupying process")

                Text("\(port.port)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 42, alignment: .leading)

                StatusBadge(text: port.statusTitle, tint: statusTint)
                    .frame(width: 76, alignment: .leading)
                    .help(statusHelp)

                VStack(alignment: .leading, spacing: 3) {
                    Text(port.processSummary)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)

                    Text(port.primaryRegistration?.purpose ?? port.ownerSummary)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.faint)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var statusTint: Color {
        if port.isOccupied {
            return AppTheme.cyan
        }

        if port.isReserved {
            return port.primaryRegistration?.isStale == true ? AppTheme.amber : AppTheme.blue
        }

        return AppTheme.mint
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: isMenuBar ? 7 : 8, style: .continuous)
            .fill(rowFill)
    }

    private var rowFill: Color {
        if isSelected {
            return AppTheme.selectedFill
        }

        if isFocused {
            return AppTheme.cyan.opacity(0.06)
        }

        return AppTheme.elevatedFill
    }

    private var rowStroke: Color {
        if isFocused {
            return AppTheme.cyan.opacity(0.42)
        }

        if isSelected {
            return AppTheme.cyan.opacity(0.30)
        }

        return AppTheme.panelStroke
    }

    private var rowHelp: String {
        let process = port.primaryProcess.map { "\($0.command) PID \($0.pid)" } ?? "No local listener"
        let usage = port.primaryRegistration.map { "\($0.tool) · \($0.projectName)" } ?? "No AI usage registration"
        return "Inspect port \(port.port). \(process). \(usage)."
    }

    private var statusHelp: String {
        if port.isOccupied {
            return "A local process is listening on this port."
        }

        if port.isReserved {
            return port.primaryRegistration?.isStale == true
                ? "AI usage exists, but it has not updated recently."
                : "AI usage is registered, but no listener is currently visible."
        }

        return "No listener or AI usage registration was found."
    }
}

struct StatusBadge: View {
    var text: String
    var tint: Color
    var isCompact = false

    var body: some View {
        Text(text)
            .font(.system(size: isCompact ? 9 : 10, weight: .bold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, isCompact ? 6 : 6)
            .padding(.vertical, isCompact ? 3 : 3)
            .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(tint.opacity(0.25)))
            .help(text)
    }
}

struct NativeEmptyState: View {
    var title: String
    var systemImage: String
    var message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppTheme.faint)

            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(AppTheme.ink)

            Text(message)
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
    }
}

struct AIUsageList: View {
    @ObservedObject var viewModel: PortMonitorViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                if viewModel.aiRegistrations.isEmpty {
                    NativeEmptyState(
                        title: "No AI usage",
                        systemImage: "sparkles.rectangle.stack",
                        message: "AI-started services appear here after whoport registration."
                    )
                    .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    ForEach(viewModel.aiRegistrations) { registration in
                        AIUsageRow(registration: registration) {
                            viewModel.inspect(registration: registration)
                        }
                    }
                }
            }
            .padding(6)
        }
    }
}

struct AIUsageRow: View {
    var registration: PortRegistration
    var inspect: () -> Void

    var body: some View {
        Button(action: inspect) {
            HStack(spacing: 8) {
                Text("\(registration.port)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 48, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(registration.tool) · \(registration.projectName)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)

                    Text(registration.purpose ?? registration.command ?? registration.projectPath)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.faint)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                StatusBadge(
                    text: registration.isStale ? "STALE" : "LIVE",
                    tint: registration.isStale ? AppTheme.amber : AppTheme.mint,
                    isCompact: true
                )
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(AppTheme.elevatedFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(AppTheme.panelStroke))
        }
        .buttonStyle(.plain)
        .help(helpText)
    }

    private var helpText: String {
        let state = registration.isStale ? "Stale registration" : "Live registration"
        let command = registration.command ?? "No command recorded"
        return "\(state). Click to inspect port \(registration.port). \(registration.tool) registered \(registration.projectName). \(command)"
    }
}
