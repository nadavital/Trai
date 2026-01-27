//
//  ExerciseTrendsChart.swift
//  Trai
//
//  Chart component showing exercise progress over time.
//

import SwiftUI
import Charts

/// A compact line chart showing exercise progress over time.
struct ExerciseTrendsChart: View {
    let history: [ExerciseHistory]
    let useLbs: Bool

    @State private var selectedMetric: Metric = .weight
    @State private var selectedRange: TimeRange = .threeMonths

    // MARK: - Types

    enum Metric: String, CaseIterable {
        case weight = "Weight"
        case volume = "Volume"
        case oneRepMax = "1RM"
    }

    enum TimeRange: String, CaseIterable {
        case oneMonth = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case oneYear = "1Y"

        var days: Int {
            switch self {
            case .oneMonth: 30
            case .threeMonths: 90
            case .sixMonths: 180
            case .oneYear: 365
            }
        }
    }

    // MARK: - Computed Properties

    private var filteredHistory: [ExerciseHistory] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -selectedRange.days, to: Date()) ?? Date()
        return history
            .filter { $0.performedAt >= cutoff }
            .sorted { $0.performedAt < $1.performedAt }
    }

    private var dataPoints: [DataPoint] {
        filteredHistory.map { entry in
            let value: Double
            switch selectedMetric {
            case .weight:
                // Use displayWeight which handles legacy records with bestSetWeightLbs = 0
                value = entry.displayWeight(usesMetric: !useLbs)
            case .volume:
                // Volume is stored in kg, convert if needed
                value = useLbs ? entry.totalVolume * WeightUtility.kgToLbs : entry.totalVolume
            case .oneRepMax:
                // 1RM is stored in kg, convert if needed
                let oneRM = entry.estimatedOneRepMax ?? 0
                value = useLbs ? WeightUtility.round(oneRM * WeightUtility.kgToLbs, unit: .lbs) : oneRM
            }
            return DataPoint(date: entry.performedAt, value: value)
        }
    }

    private var trend: (direction: TrendsService.TrendDirection, percentChange: Double) {
        guard dataPoints.count >= 2 else { return (.stable, 0) }
        let first = dataPoints.first?.value ?? 0
        let last = dataPoints.last?.value ?? 0
        return TrendsService.calculateTrend(recentAverage: last, previousAverage: first)
    }

    private var weightUnit: String {
        useLbs ? "lbs" : "kg"
    }

    private var yAxisRange: ClosedRange<Double> {
        guard !dataPoints.isEmpty else { return 0...100 }
        let values = dataPoints.map { $0.value }
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 100
        let padding = (maxVal - minVal) * 0.15
        // Round to nice numbers
        let lower = max(0, floor((minVal - padding) / 10) * 10)
        let upper = ceil((maxVal + padding) / 10) * 10
        return lower...max(upper, lower + 10)
    }

    private var currentValue: Double {
        dataPoints.last?.value ?? 0
    }

    private var startValue: Double {
        dataPoints.first?.value ?? 0
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 8) {
            // Header: Metric picker + current value + trend
            HStack {
                Picker("Metric", selection: $selectedMetric) {
                    ForEach(Metric.allCases, id: \.self) { metric in
                        Text(metric.rawValue).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 180)

                Spacer()

                if dataPoints.count >= 2 {
                    HStack(spacing: 4) {
                        Text(formatValue(currentValue))
                            .font(.subheadline)
                            .bold()
                        ExerciseTrendBadge(direction: trend.direction, change: trend.percentChange)
                    }
                }
            }

            // Chart
            if dataPoints.count >= 2 {
                chartView
            } else {
                emptyStateView
            }

            // Range picker
            Picker("Range", selection: $selectedRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var chartView: some View {
        Chart(dataPoints) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value(selectedMetric.rawValue, point.value)
            )
            .foregroundStyle(Color.accentColor)
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("Date", point.date),
                y: .value(selectedMetric.rawValue, point.value)
            )
            .foregroundStyle(Color.accentColor)
            .symbolSize(30)
        }
        .frame(height: 120)
        .chartYScale(domain: yAxisRange)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.secondary.opacity(0.3))
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(formatAxisValue(doubleValue))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.month(.narrow).day())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .foregroundStyle(.tertiary)
            Text("Not enough data in this range")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Formatting

    private func formatValue(_ value: Double) -> String {
        switch selectedMetric {
        case .weight, .oneRepMax:
            return "\(Int(value)) \(weightUnit)"
        case .volume:
            if value >= 1000 {
                return String(format: "%.1fk", value / 1000)
            }
            return "\(Int(value))"
        }
    }

    private func formatAxisValue(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.0fk", value / 1000)
        }
        return "\(Int(value))"
    }
}

// MARK: - Data Point

private struct DataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

// MARK: - Trend Badge

private struct ExerciseTrendBadge: View {
    let direction: TrendsService.TrendDirection
    let change: Double

    private var color: Color {
        switch direction {
        case .up: .green
        case .down: .orange
        case .stable: .secondary
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: direction.icon)
                .font(.caption2)
            Text("\(abs(change), format: .number.precision(.fractionLength(0)))%")
                .font(.caption2)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(color.opacity(0.15))
        .clipShape(.capsule)
    }
}

// MARK: - Preview

#Preview {
    ExerciseTrendsChart(history: [], useLbs: false)
        .padding()
}
