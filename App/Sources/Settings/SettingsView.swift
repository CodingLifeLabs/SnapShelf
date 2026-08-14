import SwiftUI
import SnapShelfConfig
import SnapShelfTypes

// Sprint 8: six-tab settings window (Information Architecture §1).
// General / Capture & Folders / OCR & Search / AI / Privacy / Advanced.

struct SettingsView: View {
    @State private var model: SettingsModel

    init(model: SettingsModel) {
        self.model = model
    }

    var body: some View {
        TabView {
            GeneralSettingsTab(settings: $model.settings)
                .tabItem { Label("General", systemImage: "gearshape") }
            CaptureSettingsTab(model: model)
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

    var body: some View {
        Form {
            Toggle("Organize screenshots into Library", isOn: $model.settings.organizeIntoLibrary)
            Toggle("Organize screen recordings", isOn: $model.settings.organizeRecordings)
            Section("Locations") {
                pathRow("Inbox", model.paths.inboxDirectory)
                pathRow("Library", model.paths.libraryDirectory)
                pathRow("Recordings", model.paths.recordingsDirectory)
            }
        }
        .padding()
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
            Section("Data locations") {
                pathRow("Database", model.paths.databaseFile)
                pathRow("Clipboard history", model.paths.clipboardHistoryFile)
                pathRow("Transfer log", model.paths.privacyLogFile)
            }
        }
        .padding()
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
