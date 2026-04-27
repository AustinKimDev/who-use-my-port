import SwiftUI

@main
struct WhoUseMyPortApp: App {
    @StateObject private var viewModel = PortMonitorViewModel()

    var body: some Scene {
        WindowGroup("Who Use My Port", id: "main") {
            ContentView(viewModel: viewModel, isCompact: false)
                .frame(
                    minWidth: 720,
                    idealWidth: 1120,
                    maxWidth: .infinity,
                    minHeight: 520,
                    idealHeight: 720,
                    maxHeight: .infinity
                )
        }
        .defaultSize(width: 1120, height: 720)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Scan") {
                    viewModel.scan()
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }

        MenuBarExtra("Ports", systemImage: "point.3.connected.trianglepath.dotted") {
            ContentView(viewModel: viewModel, isCompact: true)
                .frame(minWidth: 340, idealWidth: 380, maxWidth: 560, minHeight: 260, idealHeight: 350, maxHeight: 620)
        }
        .menuBarExtraStyle(.window)
    }
}
