//
//  WatchHeartRateCard.swift
//  Trai
//
//  Displays real-time heart rate from Apple Watch during workouts
//

import SwiftUI

/// Card showing live heart rate data from Apple Watch
struct WatchHeartRateCard: View {
    let heartRate: Double?
    let lastUpdate: Date?

    private var isStale: Bool {
        guard let lastUpdate else { return true }
        // Consider data stale if older than 30 seconds
        return Date().timeIntervalSince(lastUpdate) > 30
    }

    private var heartRateText: String {
        guard let heartRate else { return "--" }
        return "\(Int(heartRate))"
    }

    private var statusText: String {
        guard let lastUpdate else {
            return "Waiting for Apple Watch..."
        }

        if isStale {
            let seconds = Int(Date().timeIntervalSince(lastUpdate))
            if seconds < 60 {
                return "\(seconds)s ago"
            } else {
                return "\(seconds / 60)m ago"
            }
        }
        return "Live"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Heart icon with pulse animation
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: "heart.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse, options: .repeating, isActive: heartRate != nil && !isStale)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(heartRateText)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .contentTransition(.numericText())

                    Text("BPM")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    if heartRate != nil && !isStale {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                    }
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Apple Watch icon
            Image(systemName: "applewatch")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        }
        .animation(.easeInOut(duration: 0.3), value: heartRate)
    }
}

// MARK: - Preview

#Preview("With Heart Rate") {
    VStack {
        WatchHeartRateCard(heartRate: 142, lastUpdate: Date())
        WatchHeartRateCard(heartRate: 156, lastUpdate: Date().addingTimeInterval(-45))
        WatchHeartRateCard(heartRate: nil, lastUpdate: nil)
    }
    .padding()
}
