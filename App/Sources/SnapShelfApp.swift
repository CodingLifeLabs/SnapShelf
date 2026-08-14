import SwiftUI
import AppKit
import SnapShelfConfig
import SnapShelfRepo
import SnapShelfService
import SnapShelfRuntime

@main
struct SnapShelfApp: App {
    @NSApplicationDelegateAdaptor(SnapShelfAppDelegate.self) private var appDelegate

    var body: some Scene {
        // Settings scene reserved for Sprint 8. The shelf surface is an NSPanel
        // managed by the delegate (floating, non-activating).
        Settings { EmptyView() }
    }
}

@MainActor
final class SnapShelfAppDelegate: NSObject, NSApplicationDelegate {
    private var model: ShelfModel?
    private var panelController: ShelfPanelController?
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let paths = AppPaths.current()
        // Prefer SQLite+FTS5; fall back to the JSON store if the DB cannot be opened.
        let repository: any ShelfItemRepository
        if let sqlite = try? SQLiteShelfRepository(databaseURL: paths.databaseFile) {
            repository = sqlite
        } else {
            repository = FileShelfRepository(storeFile: paths.storeFile)
        }
        let pipeline = DefaultIntakePipeline(
            repository: repository,
            ocrService: VisionOCRService(),
            // Rule-based rename is local & privacy-safe, so it's on by default.
            // Cloud/on-device LLM providers are opt-in via AIServiceFactory + settings.
            aiService: RuleBasedAIService(),
            renameEnabled: true
        )
        let model = ShelfModel(paths: paths, repository: repository, pipeline: pipeline)
        self.model = model

        let panel = ShelfPanelController { ShelfView(model: model) }
        panelController = panel

        statusBarController = StatusBarController(
            onOpenShelf: { [weak panel] in panel?.show() },
            onSimulateCapture: { [weak model] in _ = model?.simulateCapture() },
            onQuit: { NSApp.terminate(nil) }
        )

        Task { @MainActor in await model.bootstrap() }
        // Show the shelf on launch so the surface is immediately visible (and screenshot-able).
        panel.show()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
