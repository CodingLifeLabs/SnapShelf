import SwiftUI
import SnapShelfRuntime
import SnapShelfTypes

struct ShelfView: View {
    let model: ShelfModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .background(.ultraThinMaterial)
        .frame(width: 340, height: 460)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Shelf")
                    .font(.headline)
                Text(model.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                _ = model.simulateCapture()
            } label: {
                Label("Capture", systemImage: "camera.viewfinder")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Write a placeholder screenshot into the inbox (simulates ⌘⇧4)")
        }
        .padding(12)
    }

    @ViewBuilder private var content: some View {
        if model.visibleItems.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(model.visibleItems) { item in
                        ShelfItemView(item: item, reduceMotion: reduceMotion)
                            .transition(itemTransition)
                    }
                }
                .padding(12)
            }
            .animation(reduceMotion ? nil : spring, value: model.visibleItems.map(\.id))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Nothing shelved yet")
                .font(.title3)
                .bold()
            Text("Press ⌘⇧4 to capture, or tap Capture to simulate one.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Simulate Capture") {
                _ = model.simulateCapture()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }

    private var spring: Animation { .spring(response: 0.4, dampingFraction: 0.82) }

    private var itemTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .scale(scale: 0.85).combined(with: .opacity),
                removal: .opacity
            )
    }
}
