import SwiftUI
import SnapShelfRuntime
import SnapShelfService
import SnapShelfTypes

// Sprint 7: maintenance surface — auto cleanup (with undo) at the top,
// near-duplicate groups (pHash) below with per-group keep/skip actions.

struct DuplicatesView: View {
    let model: ShelfModel
    @State var cleanup: CleanupModel
    @State var duplicates: DuplicatesModel

    var body: some View {
        List {
            Section("Auto Cleanup") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Resting items older than 30 days are moved to Trash — never deleted. Undo is available right after a pass.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Clean Up Now") {
                            Task { await cleanup.runCleanup(items: model.surfaced) }
                        }
                        if cleanup.canUndo {
                            Button("Undo") {
                                Task { await cleanup.undoLast() }
                            }
                        }
                        Spacer()
                    }
                    if !cleanup.statusMessage.isEmpty {
                        Text(cleanup.statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Duplicates") {
                if duplicates.isScanning {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Scanning for duplicates…")
                    }
                } else if duplicates.groups.isEmpty {
                    Text(duplicates.statusMessage.isEmpty ? "No duplicates found." : duplicates.statusMessage)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(duplicates.groups) { group in
                        DuplicateGroupRow(group: group) {
                            Task { await duplicates.resolve(group) }
                        } onSkip: {
                            duplicates.skip(group)
                        }
                    }
                }
            }
        }
        .navigationTitle("Maintenance")
        .toolbar {
            Button {
                Task { await duplicates.scan(items: model.surfaced) }
            } label: {
                Label("Scan", systemImage: "magnifyingglass")
            }
            .disabled(duplicates.isScanning)
        }
        .onAppear {
            Task { await duplicates.scan(items: model.surfaced) }
        }
    }
}

private struct DuplicateGroupRow: View {
    let group: DuplicateGroup
    let onResolve: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Keep: \(group.keeper.displayName)")
                    .font(.headline.weight(.semibold))
                Spacer()
                Button("Keep 1, Trash \(group.duplicates.count)") { onResolve() }
                Button("Skip") { onSkip() }
            }
            HStack(spacing: 12) {
                keeperCard
                ForEach(group.duplicates) { duplicate in
                    duplicateCard(duplicate)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var keeperCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            ThumbnailView(url: group.keeper.sourceURL)
                .frame(height: 70)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(alignment: .topLeading) { keepBadge }
            Text(group.keeper.displayName)
                .font(.caption2)
                .lineLimit(1)
        }
        .frame(width: 130)
    }

    private var keepBadge: some View {
        Text("KEEP")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.accentColor, in: Capsule())
            .foregroundStyle(.white)
            .padding(4)
    }

    private func duplicateCard(_ duplicate: ShelfItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ThumbnailView(url: duplicate.sourceURL)
                .frame(height: 70)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .opacity(0.7)
            Text(duplicate.displayName)
                .font(.caption2)
                .lineLimit(1)
        }
        .frame(width: 130)
    }
}
