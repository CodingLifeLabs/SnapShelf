import AppKit
import SwiftUI
import SnapShelfRuntime

// Sprint 6: standard window hosting the SwiftUI LibraryView.
// Sprint 7: also owns the maintenance/clipboard runtime models.

@MainActor
final class LibraryWindowController {
    private let window: NSWindow

    init(
        model: ShelfModel,
        library: LibraryModel,
        collections: CollectionModel,
        cleanup: CleanupModel,
        duplicates: DuplicatesModel,
        clipboard: ClipboardHistoryModel
    ) {
        let view = LibraryView(
            model: model,
            library: library,
            collections: collections,
            cleanup: cleanup,
            duplicates: duplicates,
            clipboard: clipboard
        )
        let hosting = NSHostingController(rootView: view)
        let w = NSWindow(contentViewController: hosting)
        w.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        w.title = "SnapShelf Library"
        w.isReleasedWhenClosed = false
        w.setContentSize(NSSize(width: 880, height: 560))
        self.window = w
    }

    func show() {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}
