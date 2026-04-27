import AppKit
import SwiftUI

struct StatusBar: View {
    @ObservedObject var viewModel: PortMonitorViewModel

    var body: some View {
        HStack(spacing: 7) {
            if viewModel.isScanning {
                ProgressView()
                    .controlSize(.small)
            }

            Circle()
                .fill(viewModel.errorMessage == nil ? AppTheme.mint : AppTheme.danger)
                .frame(width: 7, height: 7)
                .help(viewModel.errorMessage == nil ? "Scanner is ready." : "The last scan failed.")

            Text(viewModel.errorMessage ?? viewModel.statusText)
                .font(.caption.weight(.medium))
                .foregroundStyle(viewModel.errorMessage == nil ? AppTheme.muted : AppTheme.danger)
                .lineLimit(1)
                .help(viewModel.errorMessage ?? viewModel.statusText)

            Spacer()

            Text("⌘R Scan")
                .font(.caption2.monospaced().weight(.medium))
                .foregroundStyle(AppTheme.faint)
                .help("Keyboard shortcut for an immediate scan.")

            Divider()
                .frame(height: 14)

            Text(viewModel.selectedPIDs.isEmpty ? "No selection" : "\(viewModel.selectedPIDs.count) selected")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(viewModel.selectedPIDs.isEmpty ? AppTheme.faint : AppTheme.cyan)
                .help(viewModel.selectedPIDs.isEmpty ? "Select a listener to enable process actions." : "Selected processes can be terminated from the inspector or footer.")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .surfacePanel(cornerRadius: 10)
    }
}
