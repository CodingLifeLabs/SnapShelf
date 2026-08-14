import XCTest
@testable import SnapShelfService

// Sprint 8: BrowserURLDetector tests — script injection keeps AppleScript
// out of the test path.

final class BrowserURLDetectorTests: XCTestCase {
    func testSupportedBrowsersHaveScripts() {
        let detector = BrowserURLDetector(runScript: { script in
            // Empty script body means "browser not running"; unsupported
            // browsers must throw before the script is even consulted.
            script
        })
        for bundleID in BrowserURLDetector.supportedBrowsers {
            XCTAssertNoThrow(try detector.activeTabURL(browserBundleID: bundleID))
        }
    }

    func testDisplayName() {
        XCTAssertEqual(BrowserURLDetector.displayName(forBundleID: "com.google.Chrome"), "Chrome")
        XCTAssertEqual(BrowserURLDetector.displayName(forBundleID: "com.apple.Safari"), "Safari")
        XCTAssertEqual(BrowserURLDetector.displayName(forBundleID: "unknown.bundle"), "unknown.bundle")
    }

    func testActiveTabURLEmptyOutputReturnsNil() throws {
        let detector = BrowserURLDetector(runScript: { _ in "" })
        let url = try detector.activeTabURL(browserBundleID: "com.apple.Safari")
        XCTAssertNil(url, "empty script output means no URL available")
    }

    func testActiveTabURLParsesTrimmedOutput() throws {
        let detector = BrowserURLDetector(runScript: { _ in "  https://example.com/page?a=1  \n" })
        let url = try detector.activeTabURL(browserBundleID: "com.google.Chrome")
        XCTAssertEqual(url?.absoluteString, "https://example.com/page?a=1")
    }

    func testUnsupportedBrowserThrows() {
        let detector = BrowserURLDetector(runScript: { _ in "" })
        XCTAssertThrowsError(try detector.activeTabURL(browserBundleID: "com.unknown.Browser")) { error in
            guard case BrowserURLError.unsupportedBrowser = error else {
                return XCTFail("expected unsupportedBrowser, got \(error)")
            }
        }
    }

    func testScriptFailurePropagates() {
        struct Boom: Error {}
        let detector = BrowserURLDetector(runScript: { _ in throw Boom() })
        XCTAssertThrowsError(try detector.activeTabURL(browserBundleID: "com.apple.Safari"))
    }
}
