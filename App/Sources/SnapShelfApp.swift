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
    private var libraryController: LibraryWindowController?
    private var settingsController: SettingsWindowController?

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
            renameEnabled: true,
            // Smart Folder organizing within the app-owned library (TCC-free).
            organizer: Organizer(libraryRoot: paths.libraryDirectory)
        )
        let usageLog = UsageStatsLog(fileURL: paths.usageStatsFile)
        let model = ShelfModel(
            paths: paths,
            repository: repository,
            pipeline: pipeline,
            usageLog: usageLog
        )
        self.model = model
        wireWindows(model: model, repository: repository, paths: paths, usageLog: usageLog)
    }

    /// Build the panel/library/settings/status-bar controllers and start watching.
    private func wireWindows(
        model: ShelfModel,
        repository: any ShelfItemRepository,
        paths: AppPaths,
        usageLog: UsageStatsLog
    ) {
        let panel = ShelfPanelController { ShelfView(model: model) }
        panelController = panel

        let library = LibraryModel(libraryRoot: paths.libraryDirectory)
        let collections = CollectionModel()
        let cleanup = CleanupModel(repository: repository)
        let duplicates = DuplicatesModel(repository: repository)
        let clipboard = ClipboardHistoryModel(
            history: ClipboardHistoryRepository(storeFile: paths.clipboardHistoryFile)
        )
        let libraryController = LibraryWindowController(
            model: model,
            library: library,
            collections: collections,
            cleanup: cleanup,
            duplicates: duplicates,
            clipboard: clipboard
        )
        self.libraryController = libraryController

        let settingsModel = SettingsModel(store: AppSettingsStore(), paths: paths, usageLog: usageLog)
        let settingsController = SettingsWindowController(
            model: settingsModel,
            folderStates: model.watchedFolderStates
        )
        self.settingsController = settingsController

        // Settings edits re-resolve the watched folders (ADR-0011).
        settingsModel.onFoldersChanged = { [weak model, weak settingsModel] in
            guard let model, let settingsModel else { return }
            Task { @MainActor in
                await model.startWatchers(extraFolders: settingsModel.settings.watchedFolders)
            }
        }

        statusBarController = StatusBarController(
            onOpenShelf: { [weak panel, weak statusBarController] in
                panel?.show(on: statusBarController?.screen)
            },
            onOpenLibrary: { [weak libraryController] in libraryController?.show() },
            onOpenSettings: { [weak settingsController] in settingsController?.show() },
            onSimulateCapture: { [weak model] in _ = model?.simulateCapture() },
            onQuit: { NSApp.terminate(nil) }
        )

        // Bootstrap with the user's watch folders (ADR-0011). Settings edits re-run this.
        let folders = settingsModel.settings.watchedFolders
        Task { @MainActor in
            await model.bootstrap(extraFolders: folders)
            // Show the shelf on launch anchored to the status item's screen.
            // The status window frame is not laid out at launch — wait for it.
            for _ in 0..<10 where self.statusBarController?.screen == nil {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            panel.show(on: self.statusBarController?.screen)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
