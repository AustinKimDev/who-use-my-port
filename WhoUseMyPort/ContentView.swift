import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: PortMonitorViewModel
    var isCompact: Bool

    private let realtimeRefreshTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    @AppStorage("AppearancePreference") private var appearancePreference = AppAppearancePreference.light.rawValue

    private var appAppearance: AppAppearancePreference {
        get { AppAppearancePreference(rawValue: appearancePreference) ?? .light }
        nonmutating set { appearancePreference = newValue.rawValue }
    }

    var body: some View {
        ZStack {
            AppBackdrop()

            content
                .padding(.horizontal, isCompact ? 7 : 12)
                .padding(.top, isCompact ? 7 : 10)
                .padding(.bottom, isCompact ? 7 : 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WindowConfigurator(isResizable: isCompact))
        .preferredColorScheme(appAppearance.colorScheme)
        .onAppear {
            if viewModel.processes.isEmpty, !viewModel.isScanning {
                viewModel.scan()
            }
        }
        .onReceive(realtimeRefreshTimer) { _ in
            viewModel.refreshLivePorts()
        }
    }

    @ViewBuilder
    private var content: some View {
        if isCompact {
            CompactMenuBarView(viewModel: viewModel)
        } else {
            VStack(spacing: 8) {
                CommandCenter(
                    viewModel: viewModel,
                    appearancePreference: Binding(
                        get: { appAppearance },
                        set: { appAppearance = $0 }
                    )
                )

                AdaptiveMainContent(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                StatusBar(viewModel: viewModel)
            }
        }
    }
}

struct AdaptiveMainContent: View {
    @ObservedObject var viewModel: PortMonitorViewModel

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width < 860 {
                VStack(spacing: 8) {
                    ProcessList(viewModel: viewModel)
                        .frame(minHeight: 210, idealHeight: 260, maxHeight: 320)

                    DetailPanel(viewModel: viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                HSplitView {
                    ProcessList(viewModel: viewModel)
                        .frame(minWidth: 300, idealWidth: 350, maxWidth: 460)

                    DetailPanel(viewModel: viewModel)
                        .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}
