import SwiftUI

struct RecordedMuscleMap: View {
    let recoveryInfo: [MuscleRecoveryService.MuscleRecoveryInfo]
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selected: LiveWorkout.MuscleGroup = .chest
    private func info(_ group: LiveWorkout.MuscleGroup) -> MuscleRecoveryService.MuscleRecoveryInfo? {
        recoveryInfo.first { $0.muscleGroup == group }
    }
    private func hours(_ group: LiveWorkout.MuscleGroup) -> Int? {
        guard let value = info(group), let date = value.lastTrainedAt else { return nil }
        return max(0, Int(value.hoursSinceTraining ?? Date.now.timeIntervalSince(date) / 3600))
    }
    private func color(_ group: LiveWorkout.MuscleGroup) -> Color {
        guard let hours = hours(group) else { return Color.secondary.opacity(0.23) }
        return hours < 24 ? .red : hours < 48 ? .orange : .primary
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { geometry in
                Canvas { context, size in
                    let scale = size.width / 600
                    let transform = CGAffineTransform(scaleX: scale, y: scale)
                    let silhouette = ApprovedRecoveryVector.silhouette.applying(transform)
                    context.fill(silhouette, with: .color(.secondary.opacity(0.08)))
                    context.stroke(silhouette, with: .color(.secondary.opacity(0.25)), lineWidth: 1)
                    for (group, path) in ApprovedRecoveryVector.regions {
                        let path = path.applying(transform)
                        context.fill(path, with: .color(color(group)))
                        context.stroke(path, with: .color(group == selected ? .primary : .primary.opacity(0.12)), lineWidth: group == selected ? 1.5 : 0.5)
                    }
                }.contentShape(Rectangle()).onTapGesture { location in
                    let point = CGPoint(x: location.x * 600 / geometry.size.width, y: location.y * 600 / geometry.size.width)
                    if let region = ApprovedRecoveryVector.regions.first(where: { $0.1.contains(point) }) { selected = region.0 }
                }
                .accessibilityLabel("Front and back muscle map. Colors show elapsed time since recorded training; grey means no history.")
                .accessibilityIdentifier("recordedMuscleMap")
            }.aspectRatio(600.0 / 540.0, contentMode: .fit)
                .frame(maxWidth: sizeClass == .regular ? 330 : 260).frame(maxWidth: .infinity)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { legend }
                VStack(alignment: .leading, spacing: 6) { legend }
            }
            Menu {
                ForEach(LiveWorkout.MuscleGroup.allCases.filter { $0 != .fullBody }) { group in
                    Button(group.displayName + " · " + (hours(group).map { "\($0) h" } ?? "No history")) { selected = group }
                }
            } label: {
                HStack {
                    Circle().fill(color(selected)).frame(width: 9, height: 9)
                    Text(selected.displayName).font(.headline)
                    Spacer()
                    Text(hours(selected).map { "\($0) h" } ?? "No history").monospacedDigit()
                    Image(systemName: "chevron.up.chevron.down").font(.caption)
                }.foregroundStyle(.primary).padding(.vertical, 8)
            }.tint(.primary).accessibilityIdentifier("recoveryMuscleSelection")
            if let date = info(selected)?.lastTrainedAt {
                Text(date, format: .dateTime.month(.abbreviated).day().hour().minute()).font(.caption).foregroundStyle(.secondary)
            }
            DisclosureGroup("About this history") {
                Text("Colors show time since recorded muscle training, not measured recovery or readiness. Missing muscle history stays unknown.")
                    .font(.caption).foregroundStyle(.secondary)
            }.font(.caption)
        }.accessibilityElement(children: .contain)
    }
    private var legend: some View {
        Group {
            legendItem("<24 h", .red); legendItem("24–48 h", .orange)
            legendItem("48 h+", .primary); legendItem("No history", .secondary.opacity(0.4))
        }.font(.caption2)
    }
    private func legendItem(_ title: String, _ color: Color) -> some View {
        HStack(spacing: 4) { Circle().fill(color).frame(width: 7,height: 7); Text(title) }
    }
}

/// Navigation thumbnail of the approved SVG's front view; decorative, without a history claim.
struct RecoveryMapNavigationArtwork: View {
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 300, size.height / 540)
            let transform = CGAffineTransform(scaleX: scale, y: scale)
                .concatenating(CGAffineTransform(translationX: (size.width - 300 * scale) / 2,
                                                y: (size.height - 540 * scale) / 2))
            context.clip(to: Path(CGRect(x: (size.width - 300 * scale) / 2,
                                        y: (size.height - 540 * scale) / 2,
                                        width: 300 * scale, height: 540 * scale)))
            let silhouette = ApprovedRecoveryVector.silhouette.applying(transform)
            context.fill(silhouette, with: .color(.secondary.opacity(0.18)))
            context.stroke(silhouette, with: .color(.primary.opacity(0.45)), lineWidth: 0.45)
            for (_, region) in ApprovedRecoveryVector.regions {
                let path = region.applying(transform)
                context.fill(path, with: .color(Color(red: 0.83, green: 0.39, blue: 0.46)))
                context.stroke(path, with: .color(.primary.opacity(0.45)), lineWidth: 0.3)
            }
        }.accessibilityHidden(true)
    }
}
