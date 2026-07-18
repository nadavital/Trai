import SwiftUI

struct TraiUndoNotice: Identifiable {
    let id = UUID()
    let message: String
    let action: () -> Void
    var commit: (() -> Void)?
}

struct TraiUndoBanner: View {
    let notice: TraiUndoNotice
    let onUndo: () -> Void
    let onExpire: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.tint)

            Text(notice.message)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)

            Spacer(minLength: 4)

            Button("Undo", systemImage: "arrow.uturn.backward") {
                onUndo()
            }
            .labelStyle(.titleAndIcon)
            .buttonStyle(.glass)
            .font(.subheadline.weight(.semibold))
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dashboardUndoBanner")
        .task(id: notice.id) {
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            onExpire()
        }
    }
}
