import Foundation

/// User-tunable shelf behavior (persisted in UserDefaults in a later sprint).
public struct ShelfSettings: Sendable, Equatable, Codable {
    /// Seconds a freshly captured item stays "resting" on the shelf before stowing.
    public var hoverSeconds: Double
    /// Max surfaced/history items kept in memory for the UI.
    public var historyLimit: Int
    /// When true, resting items auto-stow after hoverSeconds.
    public var autoStow: Bool

    public init(hoverSeconds: Double = 5, historyLimit: Int = 50, autoStow: Bool = true) {
        self.hoverSeconds = hoverSeconds
        self.historyLimit = historyLimit
        self.autoStow = autoStow
    }

    public static let `default` = ShelfSettings()
}
