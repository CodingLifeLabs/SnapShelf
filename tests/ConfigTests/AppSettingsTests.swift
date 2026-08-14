import XCTest
@testable import SnapShelfConfig

// Sprint 8: AppSettings persistence round-trip tests (UserDefaults with a
// suite name keeps tests isolated from the real defaults).

final class AppSettingsTests: XCTestCase {
    var defaults: UserDefaults!
    var suiteName: String!
    var store: AppSettingsStore!

    override func setUp() {
        suiteName = "app-settings-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        store = AppSettingsStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testDefaultsWhenNothingPersisted() {
        let settings = store.load()
        XCTAssertEqual(settings, .default)
        XCTAssertFalse(settings.urlDetectionEnabled, "URL detection must be opt-in")
        XCTAssertFalse(settings.devModeEnabled, "Dev Mode must be opt-in")
        XCTAssertTrue(settings.ocrEnabled)
    }

    func testSaveLoadRoundTrip() {
        var settings = AppSettings.default
        settings.urlDetectionEnabled = true
        settings.devModeEnabled = true
        settings.aiProviderID = "openai"
        settings.ocrLanguages = ["ko-KR"]
        settings.shelfSettings.hoverSeconds = 12
        store.save(settings)
        XCTAssertEqual(store.load(), settings)
    }

    func testCorruptBlobFallsBackToDefaults() {
        defaults.set(Data([0xFF, 0xFE]), forKey: "app.settings.v1")
        XCTAssertEqual(store.load(), .default)
    }

    func testResetClearsSnapshot() {
        var settings = AppSettings.default
        settings.launchAtLogin = true
        store.save(settings)
        store.reset()
        XCTAssertEqual(store.load(), .default)
    }

    func testCustomKeyIsolation() {
        let other = AppSettingsStore(defaults: defaults, key: "other.key")
        var settings = AppSettings.default
        settings.devModeEnabled = true
        other.save(settings)
        XCTAssertEqual(store.load(), .default)
        XCTAssertTrue(other.load().devModeEnabled)
    }
}
