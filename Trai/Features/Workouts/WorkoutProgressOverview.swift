import SwiftUI

/// A small window into the same records used by the full records destination.
/// Recency selects exercises; values summarize the supplied history window.
struct WorkoutProgressOverview: View {
    let histories: [ExerciseHistory]
    let usesMetricWeight: Bool
    let volumePRMode: UserProfile.VolumePRMode
    let onRecords: () -> Void
    let onRecovery: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var recentRecords: [ExercisePR] {
        ExercisePerformanceService.snapshots(from: histories, volumePRMode: volumePRMode)
            .values
            .map { ExercisePR.from(snapshot: $0, volumePRMode: volumePRMode) }
            .sorted {
                if $0.lastPerformed != $1.lastPerformed { return $0.lastPerformed > $1.lastPerformed }
                return $0.exerciseName < $1.exerciseName
            }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        let records = recentRecords
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.indigo.gradient)
                    .frame(width: 64, height: 64)
                    .background(.indigo.opacity(0.10), in: .rect(cornerRadius: 20))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your records")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text(records.isEmpty ? "Built one workout at a time." : "Bests from recently trained exercises")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if records.isEmpty {
                Text("Log a workout to start seeing your personal bests here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(records) { record in
                        let metric = primaryMetric(for: record)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(record.exerciseName)
                                .font(.system(.headline, design: .rounded))
                            Text(metric.value)
                                .font(.system(.title3, design: .rounded, weight: .semibold))
                                .foregroundStyle(.indigo)
                            Text(metric.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                        if record.id != records.last?.id { Divider() }
                    }
                }
            }

            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(HStackLayout(spacing: 10))
            layout {
                Button("All records", systemImage: "trophy", action: onRecords)
                    .buttonStyle(.traiSecondary(fullWidth: true))
                    .accessibilityIdentifier("workoutAllRecords")
                Button("Recovery", systemImage: "waveform.path.ecg", action: onRecovery)
                    .buttonStyle(.traiTertiary(color: .primary, fullWidth: true))
            }
        }
        .traiCard(contentPadding: 20)
    }

    private func primaryMetric(for record: ExercisePR) -> (label: String, value: String) {
        if record.isActivityRecord {
            if record.maxDistanceMeters > 0 {
                // Match the full records screen; weight preference does not imply a distance unit.
                let distance = record.maxDistanceMeters >= 1000 ? record.maxDistanceMeters / 1000 : record.maxDistanceMeters
                let unit = record.maxDistanceMeters >= 1000 ? "km" : "m"
                return ("Longest distance", "\(distance.formatted(.number.precision(.fractionLength(0...2)))) \(unit)")
            }
            if record.maxDurationSeconds > 0 {
                let seconds = record.maxDurationSeconds
                let hours = seconds / 3600
                let minutes = (seconds % 3600) / 60
                let value = hours > 0 ? "\(hours) hr \(minutes) min" : (minutes > 0 ? "\(minutes) min \(seconds % 60) sec" : "\(seconds) sec")
                return ("Longest duration", value)
            }
            return ("Highest count", "\(record.maxActivityCount) \(record.maxActivityCountLabel)")
        }
        if record.maxWeightKg > 0 {
            let weight = usesMetricWeight ? record.maxWeightKg : record.maxWeightKg * WeightUtility.kgToLbs
            let unit = usesMetricWeight ? "kg" : "lbs"
            return ("Heaviest set", "\(weight.formatted(.number.precision(.fractionLength(0...1)))) \(unit) × \(record.maxWeightReps)")
        }
        if record.maxReps > 0 {
            return ("Most reps · Bodyweight", "\(record.maxReps) reps")
        }
        return ("Logged sessions", "\(record.totalSessions)")
    }
}
