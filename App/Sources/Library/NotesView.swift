import SwiftUI
import SnapShelfTypes

// Sprint 7: note editor for a shelf item. Presented as a sheet from the
// library grid; saving trims and forwards to ShelfModel.saveNote.

struct NoteEditorView: View {
    let item: ShelfItem
    let onSave: (String) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Note — \(item.displayName)")
                .font(.headline)
                .lineLimit(1)
            TextEditor(text: $text)
                .font(.body)
                .frame(minHeight: 120)
                .border(Color.secondary.opacity(0.3))
            HStack {
                if item.note != nil {
                    Text("Existing note is replaced on save.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    Task {
                        await onSave(text)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 420)
        .onAppear { text = item.note ?? "" }
    }
}
