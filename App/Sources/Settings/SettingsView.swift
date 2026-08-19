import SwiftUI
import SnapShelfConfig
import SnapShelfRuntime
import SnapShelfTypes

// Sprint 8: six-tab settings window (Information Architecture §1).
// General / Capture & Folders / OCR & Search / AI / Privacy / Advanced.

struct SettingsView: View {
    @State private var model: SettingsModel
    /// Live watch states from the shelf model; empty in previews/tests.
    @State private var folderStates: [FolderWatchState]

    init(model: SettingsModel, folderStates: [FolderWatchState] = []) {
        self.model = model
        self.folderStates = folderStates
    }

    var body: some View {
        TabView {
            GeneralSettingsTab(settings: $model.settings)
                .tabItem { Label("General", systemImage: "gearshape") }
            CaptureSettingsTab(model: model, folderStates: folderStates)
                .tabItem { Label("Capture & Folders", systemImage: "folder") }
            OCRSettingsTab(settings: $model.settings)
                .tabItem { Label("OCR & Search", systemImage: "text.magnifyingglass") }
            AISettingsTab(settings: $model.settings)
                .tabItem { Label("AI", systemImage: "sparkles") }
            PrivacySettingsTab(model: model)
                .tabItem { Label("Privacy", systemImage: "hand.raised") }
            AdvancedSettingsTab(model: model)
                .tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
        }
        .frame(minWidth: 520, minHeight: 420)
    }
}

// MARK: - Shared row builders

/// Selectable, middle-truncated filesystem path row shared by tabs.
private func pathRow(_ label: String, _ url: URL) -> some View {
    LabeledContent(label) {
        Text(url.path)
            .textSelection(.enabled)
            .lineLimit(1)
            .truncationMode(.middle)
    }
}

// MARK: - General

private struct GeneralSettingsTab: View {
    @Binding var settings: AppSettings

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $settings.launchAtLogin)
            Toggle("Show shelf on launch", isOn: $settings.showShelfOnLaunch)
            Section("Shelf behavior") {
                Stepper(
                    "Keep on shelf: \(Int(settings.shelfSettings.hoverSeconds))s",
                    value: $settings.shelfSettings.hoverSeconds,
                    in: 1...60
                )
                Stepper(
                    "History limit: \(settings.shelfSettings.historyLimit)",
                    value: $settings.shelfSettings.historyLimit,
                    in: 10...500,
                    step: 10
                )
                Toggle("Auto-stow after hover time", isOn: $settings.shelfSettings.autoStow)
            }
        }
        .padding()
    }
}

// MARK: - Capture & Folders

private struct CaptureSettingsTab: View {
    @State var model: SettingsModel
    /// Live watch states from the shelf model (nil in previews/tests).
    var folderStates: [FolderWatchState] = []

    var body: some View {
        Form {
            Toggle("Organize screenshots into Library", isOn: $model.settings.organizeIntoLibrary)
            Toggle("Organize screen recordings", isOn: $model.settings.organizeRecordings)
            Section("Watched screenshot folders") {
                ForEach(folderStates) { state in
                    HStack {
                        Image(systemName: state.state == .watching ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(state.state == .watching ? .green : .orange)
                            .accessibilityLabel(state.state == .watching ? "Watching" : "Needs permission")
                        Text(state.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        if isUserFolder(state.path) {
                            Button("Remove") { model.removeWatchedFolder(state.path) }
                                .controlSize(.small)
                        }
                    }
                }
                if folderStates.isEmpty {
                    Text("No folders watching yet — check permission prompts.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if folderStates.contains(where: { $0.state == .denied }) {
                    Label(
                        "A folder was denied. Allow SnapShelf in System Settings → Privacy & Security "
                            + "→ Files and Folders, then reopen Settings.",
                        systemImage: "lock.shield"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                Button("Add Folder…") { chooseFolder() }
            }
            Section("Locations") {
                pathRow("Inbox", model.paths.inboxDirectory)
                pathRow("Library", model.paths.libraryDirectory)
                pathRow("Recordings", model.paths.recordingsDirectory)
            }
        }
        .padding()
    }

    private func isUserFolder(_ path: String) -> Bool {
        model.settings.watchedFolders.contains(ScreenshotFolders.normalized(path))
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder to watch for new screenshots"
        if panel.runModal() == .OK, let url = panel.url {
            _ = model.addWatchedFolder(url.path, appPaths: model.paths)
        }
    }
}

// MARK: - OCR & Search

private struct OCRSettingsTab: View {
    @Binding var settings: AppSettings

    var body: some View {
        Form {
            Toggle("Run OCR on captures", isOn: $settings.ocrEnabled)
            Section("Recognition languages") {
                ForEach(settings.ocrLanguages, id: \.self) { lang in
                    Text(lang)
                }
                Text("Language list is managed automatically (English + Korean).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - AI

private struct AISettingsTab: View {
    @Binding var settings: AppSettings

    var body: some View {
        Form {
            Picker("Provider", selection: $settings.aiProviderID) {
                Text("On-device (Foundation Models)").tag("foundation-models")
                Text("Cloud (OpenAI-compatible)").tag("cloud")
                Text("Ollama (local server)").tag("ollama")
                Text("Rules only (offline)").tag("rules")
            }
            Toggle("AI rename captures", isOn: $settings.aiRenameEnabled)
            if settings.aiProviderID == "cloud" {
                Text("API keys are stored in Keychain and managed by the provider setup — never in plain settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - Privacy

private struct PrivacySettingsTab: View {
    @State var model: SettingsModel

    var body: some View {
        Form {
            Toggle("Detect browser tab URL (opt-in, AppleScript)", isOn: $model.settings.urlDetectionEnabled)
            Toggle("Keep a local transfer log", isOn: $model.settings.privacyLogEnabled)
            Section("Your usage (local only)") {
                usageSection
            }
            Section("Data locations") {
                pathRow("Database", model.paths.databaseFile)
                pathRow("Clipboard history", model.paths.clipboardHistoryFile)
                pathRow("Transfer log", model.paths.privacyLogFile)
                pathRow("Usage stats", model.paths.usageStatsFile)
            }
        }
        .padding()
        .task { await model.loadUsageSummary() }
    }

    @ViewBuilder
    private var usageSection: some View {
        if let summary = model.usageSummary {
            LabeledContent("Captured") { Text("\(summary.totalCaptured)") }
            LabeledContent("Searches") { Text("\(summary.totalSearches)") }
            LabeledContent("Search hit rate") { Text(hitRate(summary.searchHitRate)) }
            LabeledContent("Copied") { Text("\(summary.totalCopied)") }
            LabeledContent("Active days") { Text("\(summary.activeDays)") }
        } else {
            Text("Loading…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        Label(
            "This never leaves your Mac. Counts captures, searches and copies — no screenshots, names, or text.",
            systemImage: "lock"
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
        Button("Reset Usage Stats", role: .destructive) {
            Task { await model.resetUsage() }
        }
        .controlSize(.small)
    }

    private func hitRate(_ rate: Double?) -> String {
        guard let rate else { return "—" }
        return "\(Int((rate * 100).rounded()))%"
    }
}

// MARK: - Advanced

private struct AdvancedSettingsTab: View {
    @State var model: SettingsModel

    var body: some View {
        Form {
            Toggle("Dev Mode (error capture → search → Claude)", isOn: $model.settings.devModeEnabled)
            Section("Danger zone") {
                switch model.wipeStage {
                case .idle:
                    Button("Erase all data…", role: .destructive) {
                        model.requestWipe()
                    }
                case .confirmWipe:
                    Text("This permanently deletes every capture, note, and the index. Files are moved to Trash first.")
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Cancel", role: .cancel) { model.cancelWipe() }
                        Button("Erase everything", role: .destructive) {
                            model.cancelWipe()
                        }
                        .disabled(true) // wired to the wipe service after two explicit taps; placeholder until Sprint 9
                    }
                }
            }
        }
        .padding()
    }
}
