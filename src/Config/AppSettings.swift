import Foundation

// Sprint 8: full app settings persisted to UserDefaults, backing the six
// Settings tabs (General / Capture & Folders / OCR & Search / AI / Privacy /
// Advanced). Pure Codable snapshot + a store that reads/writes defaults.

/// One cloud AI provider entry as edited in the AI tab.
public struct AIProviderSetting: Sendable, Equatable, Codable, Identifiable {
    public var id: String
    public var enabled: Bool
    public var apiKeyPresent: Bool

    public init(id: String, enabled: Bool, apiKeyPresent: Bool) {
        self.id = id
        self.enabled = enabled
        self.apiKeyPresent = apiKeyPresent
    }
}

/// Snapshot of every user-tunable setting.
public struct AppSettings: Sendable, Equatable, Codable {
    // General
    public var launchAtLogin: Bool
    public var showShelfOnLaunch: Bool
    public var shelfSettings: ShelfSettings

    // Capture & Folders
    public var organizeIntoLibrary: Bool
    public var organizeRecordings: Bool
    /// User-added watch folders (absolute paths). App-owned paths are rejected (ADR-0011).
    public var watchedFolders: [String]

    // OCR & Search
    public var ocrEnabled: Bool
    public var ocrLanguages: [String]

    // AI
    public var aiProviderID: String
    public var aiRenameEnabled: Bool

    // Privacy
    public var urlDetectionEnabled: Bool
    public var privacyLogEnabled: Bool

    // Advanced
    public var devModeEnabled: Bool

    public init(
        launchAtLogin: Bool = false,
        showShelfOnLaunch: Bool = true,
        shelfSettings: ShelfSettings = .default,
        organizeIntoLibrary: Bool = true,
        organizeRecordings: Bool = true,
        watchedFolders: [String] = [],
        ocrEnabled: Bool = true,
        ocrLanguages: [String] = ["en-US", "ko-KR"],
        aiProviderID: String = "foundation-models",
        aiRenameEnabled: Bool = true,
        urlDetectionEnabled: Bool = false,
        privacyLogEnabled: Bool = true,
        devModeEnabled: Bool = false
    ) {
        self.launchAtLogin = launchAtLogin
        self.showShelfOnLaunch = showShelfOnLaunch
        self.shelfSettings = shelfSettings
        self.organizeIntoLibrary = organizeIntoLibrary
        self.organizeRecordings = organizeRecordings
        self.watchedFolders = watchedFolders
        self.ocrEnabled = ocrEnabled
        self.ocrLanguages = ocrLanguages
        self.aiProviderID = aiProviderID
        self.aiRenameEnabled = aiRenameEnabled
        self.urlDetectionEnabled = urlDetectionEnabled
        self.privacyLogEnabled = privacyLogEnabled
        self.devModeEnabled = devModeEnabled
    }

    public static let `default` = AppSettings()
}

/// Reads/writes the settings snapshot in UserDefaults as one JSON blob —
/// a single key keeps migrations trivial.
public final class AppSettingsStore: @unchecked Sendable {
    // UserDefaults is documented thread-safe; the stored key is immutable.
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "app.settings.v1") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> AppSettings {
        guard let data = defaults.data(forKey: key) else { return .default }
        return (try? JSONDecoder().decode(AppSettings.self, from: data)) ?? .default
    }

    public func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }

    /// Remove the persisted snapshot (Advanced → Reset Settings).
    public func reset() {
        defaults.removeObject(forKey: key)
    }
}
