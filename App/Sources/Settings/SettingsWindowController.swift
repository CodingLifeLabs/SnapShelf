import AppKit
import SwiftUI

// Sprint 8: standard window hosting the six-tab SettingsView.

@MainActor
final class SettingsWindowController {
    private let window: NSWindow

    init(model: SettingsModel) {
        let hosting = NSHostingController(rootView: SettingsView(model: model))
        let w = NSWindow(contentViewController: hosting)
        w.styleMask = [.titled, .closable, .miniaturizable]
        w.title = "SnapShelf Settings"
        w.isReleasedWhenClosed = false
        w.setContentSize(NSSize(width: 560, height: 460))
        self.window = w
    }

    func show() {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}
