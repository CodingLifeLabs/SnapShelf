import Foundation

// Sprint 8: active-browser tab URL detection, opt-in. Uses AppleScript against
// the frontmost browser; the caller supplies the script runner so tests can
// inject canned output. Pure protocol-based — no AppKit dependency here.

/// Reads the frontmost tab URL of a known browser via AppleScript.
public struct BrowserURLDetector: Sendable {
    /// AppleScript fragment per supported browser bundle id.
    private static let scripts: [String: String] = [
        "com.apple.Safari":
            "tell application \"Safari\" to get URL of front document",
        "com.google.Chrome":
            "tell application \"Google Chrome\" to get URL of active tab of front window",
        "org.mozilla.firefox":
            "tell application \"Firefox\" to get URL of front window",
        "company.thebrowser.Browser":
            "tell application \"Arc\" to get URL of front window"
    ]

    /// Supported browser bundle ids, display order.
    public static let supportedBrowsers: [String] = [
        "com.apple.Safari",
        "com.google.Chrome",
        "org.mozilla.firefox",
        "company.thebrowser.Browser"
    ]

    /// Friendly name for a bundle id ("com.google.Chrome" → "Chrome").
    public static func displayName(forBundleID bundleID: String) -> String {
        switch bundleID {
        case "com.apple.Safari": return "Safari"
        case "com.google.Chrome": return "Chrome"
        case "org.mozilla.firefox": return "Firefox"
        case "company.thebrowser.Browser": return "Arc"
        default: return bundleID
        }
    }

    private let runScript: @Sendable (String) throws -> String

    /// - Parameters:
    ///   - runScript: executes an AppleScript source string, returning its text result.
    public init(runScript: @escaping @Sendable (String) throws -> String = { source in
        let script = NSAppleScript(source: source)
        var errorInfo: NSDictionary?
        let output = script?.executeAndReturnError(&errorInfo)
        if let errorInfo { throw BrowserURLError.scriptFailed(description: errorInfo.description) }
        return output?.stringValue ?? ""
    }) {
        self.runScript = runScript
    }

    /// Returns the front tab URL for the given browser, or nil if unavailable.
    public func activeTabURL(browserBundleID: String) throws -> URL? {
        guard let source = Self.scripts[browserBundleID] else {
            throw BrowserURLError.unsupportedBrowser(browserBundleID)
        }
        let raw = try runScript(source)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(string: raw)
    }
}

public enum BrowserURLError: Error, Equatable {
    case unsupportedBrowser(String)
    case scriptFailed(description: String)
}
