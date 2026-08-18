import Foundation
import Observation
import SnapShelfConfig
import SnapShelfRuntime
import SnapShelfTypes

// Sprint 8: settings runtime. Loads the persisted snapshot, exposes it for
// two-way binding from the six tabs, and saves on every change.

@MainActor
@Observable
final class SettingsModel {
    var settings: AppSettings {
        didSet { store.save(settings) }
    }

    private let store: AppSettingsStore
    let paths: AppPaths

    /// Two-stage confirmation state for destructive actions.
    enum ResetStage: Equatable {
        case idle
        case confirmWipe
    }
    var wipeStage: ResetStage = .idle

    /// Fired whenever watch folders change so the app can re-resolve watchers.
    var onFoldersChanged: (@MainActor () -> Void)?

    init(store: AppSettingsStore = AppSettingsStore(), paths: AppPaths = .current()) {
        self.store = store
        self.paths = paths
        self.settings = store.load()
    }

    /// Re-read from disk (Advanced → Reload).
    func reload() {
        settings = store.load()
    }

    // MARK: - Watch folders (Sprint 11 / ADR-0011)

    /// Add a user watch folder. Returns false for app-owned paths (rejected) or duplicates.
    @discardableResult
    func addWatchedFolder(_ path: String, appPaths: AppPaths) -> Bool {
        guard !ScreenshotFolders.isProtected(path, appPaths: appPaths) else { return false }
        let normalized = ScreenshotFolders.normalized(path)
        guard !settings.watchedFolders.contains(normalized) else { return false }
        settings.watchedFolders.append(normalized)
        onFoldersChanged?()
        return true
    }

    /// Remove a user watch folder (system-resolved folders are not listed here).
    func removeWatchedFolder(_ path: String) {
        let normalized = ScreenshotFolders.normalized(path)
        settings.watchedFolders.removeAll { $0 == normalized }
        onFoldersChanged?()
    }

    /// Stage 1 → Stage 2. The view requires two explicit taps before wiping.
    func requestWipe() {
        wipeStage = .confirmWipe
    }

    func cancelWipe() {
        wipeStage = .idle
    }
}
