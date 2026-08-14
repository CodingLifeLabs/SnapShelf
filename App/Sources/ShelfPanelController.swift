import AppKit
import SwiftUI

/// Floating, non-activating bottom-right panel that hosts the SwiftUI shelf surface.
@MainActor
public final class ShelfPanelController: NSObject {
    private let panel: NSPanel
    private let hostingController: NSHostingController<AnyView>
    private let panelSize = NSSize(width: 340, height: 460)

    public init<Content: View>(@ViewBuilder content: () -> Content) {
        let host = NSHostingController(rootView: AnyView(content()))
        self.hostingController = host
        let p = NSPanel(contentViewController: host)
        self.panel = p
        super.init()
        configurePanel()
    }

    private func configurePanel() {
        panel.styleMask = [.nonactivatingPanel, .titled, .closable, .fullSizeContentView, .borderless]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.setContentSize(panelSize)
    }

    public func show() {
        guard let screen = NSScreen.main else {
            panel.orderFrontRegardless()
            return
        }
        let visible = screen.visibleFrame
        panel.setContentSize(panelSize)
        let origin = NSPoint(
            x: visible.maxX - panel.frame.width - 24,
            y: visible.minY + 24
        )
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
    }

    public func hide() {
        panel.orderOut(nil)
    }

    public func toggle() {
        if panel.isOnActiveSpace && panel.isVisible { hide() } else { show() }
    }

    public var isVisible: Bool { panel.isVisible }
}
