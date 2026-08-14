import AppKit

/// Menu bar status item with the core menu (Open Shelf / Simulate Capture / Quit).
@MainActor
public final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let onOpenShelf: @MainActor () -> Void
    private let onOpenLibrary: @MainActor () -> Void
    private let onOpenSettings: @MainActor () -> Void
    private let onSimulateCapture: @MainActor () -> Void
    private let onQuit: @MainActor () -> Void

    public init(
        systemSymbolName: String = "rectangle.stack",
        onOpenShelf: @escaping @MainActor () -> Void,
        onOpenLibrary: @escaping @MainActor () -> Void,
        onOpenSettings: @escaping @MainActor () -> Void = {},
        onSimulateCapture: @escaping @MainActor () -> Void,
        onQuit: @escaping @MainActor () -> Void
    ) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.onOpenShelf = onOpenShelf
        self.onOpenLibrary = onOpenLibrary
        self.onOpenSettings = onOpenSettings
        self.onSimulateCapture = onSimulateCapture
        self.onQuit = onQuit
        super.init()

        let icon = NSImage(systemSymbolName: systemSymbolName, accessibilityDescription: "SnapShelf")
        icon?.isTemplate = true
        statusItem.button?.image = icon
        statusItem.button?.toolTip = "SnapShelf"

        let menu = NSMenu()
        menu.addItem(item("Open Shelf", action: #selector(handleOpenShelf), key: "o"))
        menu.addItem(item("Open Library", action: #selector(handleOpenLibrary), key: "l"))
        menu.addItem(item("Settings…", action: #selector(handleOpenSettings), key: ","))
        menu.addItem(item("Simulate Capture", action: #selector(handleSimulate), key: "s"))
        menu.addItem(.separator())
        menu.addItem(item("Quit SnapShelf", action: #selector(handleQuit), key: "q"))
        statusItem.menu = menu
    }

    private func item(_ title: String, action: Selector, key: String) -> NSMenuItem {
        let mi = NSMenuItem(title: title, action: action, keyEquivalent: key)
        mi.target = self
        return mi
    }

    @objc private func handleOpenShelf() { onOpenShelf() }
    @objc private func handleOpenLibrary() { onOpenLibrary() }
    @objc private func handleOpenSettings() { onOpenSettings() }
    @objc private func handleSimulate() { onSimulateCapture() }
    @objc private func handleQuit() { onQuit() }
}
