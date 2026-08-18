import AppKit
import SwiftUI
import SnapShelfRuntime

// Sprint 8: standard window hosting the six-tab SettingsView.

@MainActor
final class SettingsWindowController {
    private let window: NSWindow

    init(model: SettingsModel, folderStates: [FolderWatchState] = []) {
        let hosting = NSHostingController(
            rootView: SettingsView(model: model, folderStates: folderStates)
        )
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
