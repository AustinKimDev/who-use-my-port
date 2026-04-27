import AppKit
import SwiftUI

enum AppAppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

enum AppTheme {
    static let ink = Color.primary
    static let muted = Color.secondary
    static let faint = Color.secondary.opacity(0.58)
    static let accent = Color(red: 0.05, green: 0.56, blue: 0.62)
    static let cyan = accent
    static let blue = Color(red: 0.16, green: 0.36, blue: 0.74)
    static let violet = Color(red: 0.43, green: 0.38, blue: 0.78)
    static let success = Color(red: 0.15, green: 0.58, blue: 0.28)
    static let mint = success
    static let warning = Color.orange.opacity(0.88)
    static let amber = warning
    static let danger = Color.red.opacity(0.86)
    static let panelStroke = Color(nsColor: .separatorColor).opacity(0.65)
    static let panelFill = Color(nsColor: .textBackgroundColor)
    static let elevatedFill = Color(nsColor: .controlBackgroundColor)
    static let selectedFill = Color(red: 0.05, green: 0.56, blue: 0.62).opacity(0.12)
}

struct AppBackdrop: View {
    var body: some View {
        Color(nsColor: .windowBackgroundColor)
            .ignoresSafeArea()
    }
}

struct WindowConfigurator: NSViewRepresentable {
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

        window.isOpaque = true
        window.backgroundColor = .windowBackgroundColor
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

struct SurfacePanel: ViewModifier {
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppTheme.panelFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.panelStroke)
            )
    }
}

extension View {
    func surfacePanel(cornerRadius: CGFloat = 20) -> some View {
        modifier(SurfacePanel(cornerRadius: cornerRadius))
    }
}
