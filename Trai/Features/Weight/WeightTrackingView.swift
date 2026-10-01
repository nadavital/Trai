//
//  WeightTrackingView.swift
//  Trai
//
//  Created by Nadav Avital on 12/25/25.
//

import SwiftUI
import SwiftData
import Charts

struct WeightTrackingView: View {
    var embedded = false
    @Query(sort: \WeightEntry.loggedAt, order: .reverse)
    private var weightEntries: [WeightEntry]

    @Query private var profiles: [UserProfile]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitService.self) private var healthKitService: HealthKitService?
    @State private var showingAddWeight = false
    @State private var selectedTimeRange: TimeRange = .month

    enum TimeRange: String, CaseIterable, Identifiable {
        case week = "Week"
        case month = "Month"
        case threeMonths = "3 Months"
        case year = "Year"

        var id: String { rawValue }

        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 90
            case .year: return 365
            }
        }
    }

    private var profile: UserProfile? { profiles.first }

    private var useLbs: Bool {
        !(profile?.usesMetricWeight ?? true)
    }

    private var weightUnit: String {
        useLbs ? "lb" : "kg"
    }

    private func displayWeight(_ weightKg: Double) -> Double {
        useLbs ? weightKg * 2.20462 : weightKg
    }

    private var filteredEntries: [WeightEntry] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -selectedTimeRange.days, to: Date()) ?? Date()
        return weightEntries.filter { $0.loggedAt >= cutoffDate }
    }

    var body: some View {
        if embedded {
            historyContent
        } else {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 20) {
                        // Current weight card
                        if let latest = weightEntries.first {
                            CurrentWeightCard(
                                entry: latest,
                                targetWeight: profile?.targetWeightKg,
                                useLbs: useLbs
                            )
                        }

                        historyContent
                    }
                    .padding()
                }
                .navigationTitle("Weight")
                .toolbarTitleDisplayMode(.inlineLarge)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", systemImage: "checkmark") { dismiss() }
                            .labelStyle(.iconOnly)
                            .tint(.accentColor)
                            .accessibilityIdentifier("weightHistoryDone")
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Log weight", systemImage: "plus") {
                            showingAddWeight = true
                        }
                    }
                }
                .sheet(isPresented: $showingAddWeight) {
                    LogWeightSheet()
                        .traiSheetBranding()
                }
                .refreshable {
                    await syncHealthKit()
                }
            }
            .traiBackground()
        }
    }

    private var historyContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
            Text("History").font(.headline)
            Spacer()
            Picker("Time Range", selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.menu)
            .tint(.primary)
            }

            // Weight chart
            if filteredEntries.count > 1 {
                WeightChartView(
                    entries: filteredEntries.reversed(),
                    targetWeight: profile?.targetWeightKg,
                    useLbs: useLbs
                )
            }

            // Weight history list
            WeightHistoryList(entries: filteredEntries, useLbs: useLbs)
        }
        .accessibilityIdentifier("weightInlineHistory")
    }

    private func syncHealthKit() async {
        guard let healthKitService else { return }

        do {
            let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
            let healthKitEntries = try await healthKitService.fetchWeightEntriesAuthorized(from: threeMonthsAgo, to: Date())

            let existingIDs = Set(weightEntries.compactMap { $0.healthKitSampleID })
            let newEntries = healthKitEntries.filter { !existingIDs.contains($0.healthKitSampleID ?? "") }

            for entry in newEntries {
                modelContext.insert(entry)
            }
        } catch {
            // Handle error silently
        }
    }
}

// MARK: - Current Weight Card

struct CurrentWeightCard: View {
    let entry: WeightEntry
    let targetWeight: Double?
    var useLbs: Bool = false

    private var displayWeight: Double {
        useLbs ? entry.weightKg * 2.20462 : entry.weightKg
    }

    private var displayTarget: Double? {
        guard let target = targetWeight else { return nil }
        return useLbs ? target * 2.20462 : target
    }

    private var weightUnit: String {
        useLbs ? "lb" : "kg"
    }

    @ScaledMetric(relativeTo: .largeTitle) private var weightFontSize: CGFloat = 42

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Latest weight")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(displayWeight, format: .number.precision(.fractionLength(1)))
                    .font(.system(size: weightFontSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                Text(weightUnit)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            Text(entry.loggedAt, format: .dateTime.month().day().hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .traiCard(contentPadding: 18)
    }
}

// MARK: - Weight Chart View

struct WeightChartView: View {
    let entries: [WeightEntry]
    let targetWeight: Double?
    var useLbs: Bool = false

    private func displayWeight(_ weightKg: Double) -> Double {
        useLbs ? weightKg * 2.20462 : weightKg
    }

    private var weightUnit: String {
        useLbs ? "lb" : "kg"
    }

    /// Computes the Y-axis domain with padding around the data range
    private var yAxisDomain: ClosedRange<Double> {
        let weights = entries.map { displayWeight($0.weightKg) }
        var minWeight = weights.min() ?? 0
        var maxWeight = weights.max() ?? 100

        // Include target weight in range if present
        if let target = targetWeight {
            let displayTarget = displayWeight(target)
            minWeight = min(minWeight, displayTarget)
            maxWeight = max(maxWeight, displayTarget)
        }

        // Add padding (5% of range or minimum of 2 units)
        let range = maxWeight - minWeight
        let padding = max(range * 0.1, useLbs ? 5 : 2)

        return (minWeight - padding)...(maxWeight + padding)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Check-ins").font(.subheadline.weight(.semibold))
                Spacer()
                Text(weightUnit).font(.caption).foregroundStyle(.secondary)
            }

            Chart {
                ForEach(entries) { entry in
                    AreaMark(
                        x: .value("Date", entry.loggedAt),
                        yStart: .value("Baseline", yAxisDomain.lowerBound),
                        yEnd: .value("Weight", displayWeight(entry.weightKg))
                    )
                    .foregroundStyle(LinearGradient(colors: [.accentColor.opacity(0.18), .accentColor.opacity(0.01)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
                    LineMark(
                        x: .value("Date", entry.loggedAt),
                        y: .value("Weight", displayWeight(entry.weightKg))
                    )
                    .foregroundStyle(Color.accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)

                    PointMark(
                        x: .value("Date", entry.loggedAt),
                        y: .value("Weight", displayWeight(entry.weightKg))
                    )
                    .foregroundStyle(Color.accentColor)
                    .symbolSize(24)
                }

                if let target = targetWeight {
                    RuleMark(y: .value("Goal", displayWeight(target)))
                        .foregroundStyle(.secondary.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                }
            }
            .frame(height: 150)
            .chartYScale(domain: yAxisDomain)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 4])).foregroundStyle(Color.secondary.opacity(0.14))
                    AxisValueLabel().font(.caption2)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { value in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day()).font(.caption2)
                }
            }
        }
        .traiCard(contentPadding: 18)
    }
}

// MARK: - Weight History List

struct WeightHistoryList: View {
    let entries: [WeightEntry]
    var useLbs: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent entries")
                .font(.subheadline.weight(.semibold))

            if entries.isEmpty {
                Text("No weight entries yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(entries) { entry in
                    WeightEntryRow(entry: entry, useLbs: useLbs)
                }
            }
        }
        .traiCard(contentPadding: 18)
    }
}

struct WeightEntryRow: View {
    let entry: WeightEntry
    var useLbs: Bool = false

    private var displayWeight: Double {
        useLbs ? entry.weightKg * 2.20462 : entry.weightKg
    }

    private var weightUnit: String {
        useLbs ? "lb" : "kg"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.loggedAt, format: .dateTime.weekday(.abbreviated).month().day())
                    .font(.body)

                if entry.sourceIsHealthKit {
                    Label("From Apple Health", systemImage: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            Text("\(displayWeight, format: .number.precision(.fractionLength(1))) \(weightUnit)")
                .font(.headline)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    WeightTrackingView()
        .modelContainer(for: [WeightEntry.self, UserProfile.self], inMemory: true)
}
