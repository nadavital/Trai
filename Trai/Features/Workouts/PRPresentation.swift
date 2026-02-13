import SwiftUI

/// Shared visual semantics for PR metrics across workout surfaces.
enum PRMetricKind {
    case weight
    case reps
    case volume
    case estimatedOneRepMax

    var label: String {
        switch self {
        case .weight:
            return "Weight PR"
        case .reps:
            return "Rep PR"
        case .volume:
            return "Volume PR"
        case .estimatedOneRepMax:
            return "Est. 1RM"
        }
    }

    var iconName: String {
        switch self {
        case .weight:
            return "scalemass.fill"
        case .reps:
            return "number.circle.fill"
        case .volume:
            return "chart.bar.fill"
        case .estimatedOneRepMax:
            return "trophy.fill"
        }
    }

    var color: Color {
        switch self {
        case .weight:
            return .orange
        case .reps:
            return .blue
        case .volume:
            return .green
        case .estimatedOneRepMax:
            return .yellow
        }
    }
}

extension LiveWorkoutViewModel.PRType {
    var metricKind: PRMetricKind {
        switch self {
        case .weight:
            return .weight
        case .reps:
            return .reps
        case .volume:
            return .volume
        }
    }
}
