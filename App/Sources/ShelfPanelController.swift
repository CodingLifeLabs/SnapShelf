import AppKit
import SwiftUI

/// Floating, non-activating bottom-right panel that hosts the SwiftUI shelf surface.
@MainActor
public final class ShelfPanelController: NSObject {
    private let panel: NSPanel
    private let hostingController: NSHostingController<AnyView>
    // SwiftUI shelf content measured 488pt tall at default settings (Sprint 11 EVAL);
    // 460 clipped the bottom row by 4px after the SwiftUI layout settled.
    private let panelSize = NSSize(width: 340, height: 492)

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
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.setContentSize(panelSize)
    }

    /// Show anchored to a specific screen (e.g. the status item's screen).
    /// Falls back to the main screen, then to just ordering the panel front.
    public func show(on preferredScreen: NSScreen?) {
        let screen = preferredScreen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else {
            panel.orderFrontRegardless()
            return
        }
        NSApp.activate()
        let visible = screen.visibleFrame
        panel.setContentSize(panelSize)
        let origin = NSPoint(
            x: visible.maxX - panel.frame.width - 24,
            y: visible.minY + 24
        )
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
    }

    public func show() {
        show(on: nil)
    }

    public func hide() {
        panel.orderOut(nil)
    }

    public func toggle() {
        if panel.isOnActiveSpace && panel.isVisible { hide() } else { show() }
    }

    public var isVisible: Bool { panel.isVisible }
}
