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

    init(store: AppSettingsStore = AppSettingsStore(), paths: AppPaths = .current()) {
        self.store = store
        self.paths = paths
        self.settings = store.load()
    }

    /// Re-read from disk (Advanced → Reload).
    func reload() {
        settings = store.load()
    }

    /// Stage 1 → Stage 2. The view requires two explicit taps before wiping.
    func requestWipe() {
        wipeStage = .confirmWipe
    }

    func cancelWipe() {
        wipeStage = .idle
    }
}
