//
//  CardioExerciseCard.swift
//  Trai
//
//  Category-aware non-strength exercise card for live workout tracking.
//

import SwiftUI

struct CardioExerciseCard: View {
    let entry: LiveWorkoutEntry
    let usesMetricWeight: Bool
    let onUpdateDuration: (Int) -> Void
    let onUpdateDistance: (Double) -> Void
    var onUpdateSetCount: ((Int?) -> Void)?
    var onUpdateReps: ((Int?) -> Void)?
    var onUpdateWeightKg: ((Double?) -> Void)?
    var onUpdateNotes: ((String) -> Void)?
    var onAddSegment: (() -> Void)?
    var onUpdateSegmentDuration: ((Int, Int) -> Void)?
    var onUpdateSegmentDistance: ((Int, Double) -> Void)?
    var onUpdateSegmentReps: ((Int, Int) -> Void)?
    var onUpdateSegmentWeightKg: ((Int, Double) -> Void)?
    var onUpdateSegmentNotes: ((Int, String) -> Void)?
    var onRemoveSegment: ((Int) -> Void)?
    var onDeleteExercise: (() -> Void)? = nil

    @State private var isExpanded = true
    @State private var showDeleteConfirmation = false
    @State private var didEnsureInitialSegment = false
    @State private var durationMinutes = ""
    @State private var durationSeconds = ""
    @State private var distanceKm = ""
    @State private var sets = ""
    @State private var reps = ""
    @State private var weight = ""
    @State private var notes = ""
    @State private var showNotesField = false

    private var fields: [Exercise.TrackingField] {
        entry.trackingFields
    }

    private var weightUnit: WeightUnit {
        WeightUnit(usesMetric: usesMetricWeight)
    }

    private var weightUnitLabel: String {
        usesMetricWeight ? "kg" : "lbs"
    }

    private var countUnitLabel: String {
        switch entry.resolvedActivityCategory {
        case .conditioning:
            return "rounds"
        case .sportPractice, .skill:
            return "attempts"
        default:
            return "reps"
        }
    }

    private var countRowTitle: String {
        countUnitLabel.capitalized
    }

    private var supportsSegments: Bool {
        fields.contains(.duration)
            || fields.contains(.distance)
            || fields.contains(.reps)
            || fields.contains(.weight)
            || fields.contains(.notes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if isExpanded {
                VStack(spacing: 12) {
                    if supportsSegments {
                        segmentsSection

                        Button {
                            onAddSegment?()
                        } label: {
                            Label("Add segment", systemImage: "plus.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.traiTertiary(color: .accentColor, fullWidth: true))
                    } else {
                        if fields.contains(.sets) {
                            setsRow
                        }
                        if fields.contains(.duration) {
                            durationRow
                        }
                        if fields.contains(.distance) {
                            distanceRow
                        }
                        if fields.contains(.reps) {
                            repsRow
                        }
                        if fields.contains(.weight) {
                            weightRow
                        }
                        if fields.contains(.notes) {
                            notesRow
                        }
                    }
                }
            }
        }
        .traiCard()
        .onAppear {
            syncFieldsFromEntry()
            ensureInitialSegment()
        }
        .confirmationDialog(
            "Remove \(entry.exerciseName)?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove Activity", role: .destructive) {
                onDeleteExercise?()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var header: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: entry.activityIconName)
                        .font(.subheadline)
                        .foregroundStyle(.accent)
                        .frame(width: 28, height: 28)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.exerciseName)
                            .font(.headline)

                        if shouldShowActivitySubtitle {
                            Text(entry.activityTypeName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if !plannedHeaderSegments.isEmpty {
                            Text(plannedHeaderSegments.joined(separator: " • "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if onDeleteExercise != nil {
                Menu {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Remove Activity", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
            }
        }
    }

    private var shouldShowActivitySubtitle: Bool {
        let activityName = entry.activityTypeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !activityName.isEmpty else { return false }
        return activityName.goalNormalizedKey != entry.exerciseName.goalNormalizedKey
    }

    private var plannedHeaderSegments: [String] {
        guard entry.isPlannedActivityGuidance else { return [] }
        return entry.plannedActivitySummarySegments.filter {
            $0.goalNormalizedKey != entry.activityTypeName.goalNormalizedKey
        }
    }

    private var durationRow: some View {
        trackingRow(icon: "clock.fill", title: "Duration") {
            HStack(spacing: 4) {
                compactNumberField("00", text: $durationMinutes, width: 40)
                    .onChange(of: durationMinutes) { _, _ in updateDuration() }
                Text(":").foregroundStyle(.secondary)
                compactNumberField("00", text: $durationSeconds, width: 40)
                    .onChange(of: durationSeconds) { _, _ in updateDuration() }
            }
        }
    }

    private var distanceRow: some View {
        trackingRow(icon: "map.fill", title: "Distance") {
            HStack(spacing: 4) {
                compactNumberField("0.00", text: $distanceKm, width: 64, keyboard: .decimalPad)
                    .onChange(of: distanceKm) { _, newValue in
                        if let km = Double(newValue) {
                            onUpdateDistance(km * 1000)
                        }
                    }
                Text("km")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var repsRow: some View {
        trackingRow(icon: "repeat", title: countRowTitle) {
            compactNumberField("0", text: $reps, width: 58)
                .onChange(of: reps) { _, newValue in
                    onUpdateReps?(Int(newValue))
                }
        }
    }

    private var setsRow: some View {
        trackingRow(icon: "number", title: "Sets / Sections") {
            compactNumberField("0", text: $sets, width: 58)
                .onChange(of: sets) { _, newValue in
                    onUpdateSetCount?(Int(newValue))
                }
        }
    }

    private var weightRow: some View {
        trackingRow(icon: "scalemass.fill", title: "Weight") {
            HStack(spacing: 4) {
                compactNumberField("0", text: $weight, width: 64, keyboard: .decimalPad)
                    .onChange(of: weight) { _, newValue in
                        guard let value = Double(newValue) else {
                            onUpdateWeightKg?(nil)
                            return
                        }
                        let kg = usesMetricWeight ? value : value / WeightUtility.kgToLbs
                        onUpdateWeightKg?(kg)
                    }
                Text(weightUnitLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var notesRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showNotesField.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: notes.isEmpty ? "note.text.badge.plus" : "note.text")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(notes.isEmpty ? Color.secondary : Color.accentColor)

                    Text(notes.isEmpty ? "Add notes" : "Notes")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(notes.isEmpty ? .secondary : .primary)

                    Spacer()

                    Image(systemName: showNotesField ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(notes.isEmpty ? "Add activity notes" : "Edit activity notes")

            if showNotesField || !notes.isEmpty {
                TextField("Add context", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                    .onChange(of: notes) { _, value in
                        onUpdateNotes?(value)
                    }
            }
        }
    }

    private var segmentsSection: some View {
        VStack(spacing: 6) {
            ForEach(Array(entry.activitySegments.enumerated()), id: \.element.id) { index, segment in
                ActivitySegmentRow(
                    index: index,
                    segment: segment,
                    fields: fields,
                    usesMetricWeight: usesMetricWeight,
                onUpdateDuration: { seconds in onUpdateSegmentDuration?(index, seconds) },
                onUpdateDistance: { meters in onUpdateSegmentDistance?(index, meters) },
                onUpdateReps: { reps in onUpdateSegmentReps?(index, reps) },
                onUpdateWeightKg: { weight in onUpdateSegmentWeightKg?(index, weight) },
                onUpdateNotes: { notes in onUpdateSegmentNotes?(index, notes) },
                    onRemove: { onRemoveSegment?(index) },
                    countUnitLabel: countUnitLabel
                )
            }
        }
    }

    private func trackingRow<Content: View>(
        icon: String,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)

            Spacer()

            content()
        }
    }

    private func compactNumberField(
        _ placeholder: String,
        text: Binding<String>,
        width: CGFloat,
        keyboard: UIKeyboardType = .numberPad
    ) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .multilineTextAlignment(.center)
            .frame(width: width)
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
    }

    private func updateDuration() {
        let mins = Int(durationMinutes) ?? 0
        let secs = Int(durationSeconds) ?? 0
        onUpdateDuration(mins * 60 + secs)
    }

    private func syncFieldsFromEntry() {
        let trackedSeconds = entry.trackedDurationSeconds
        if trackedSeconds > 0 {
            let seconds = trackedSeconds
            durationMinutes = "\(seconds / 60)"
            durationSeconds = String(format: "%02d", seconds % 60)
        }
        let trackedMeters = entry.trackedDistanceMeters
        if trackedMeters > 0 {
            let meters = trackedMeters
            distanceKm = String(format: "%.2f", meters / 1000)
        }
        if let firstSet = entry.sets.first {
            if !entry.sets.isEmpty {
                sets = "\(entry.sets.count)"
            }
            if firstSet.reps > 0 {
                reps = "\(firstSet.reps)"
            }
            let displayWeight = firstSet.displayWeight(usesMetric: usesMetricWeight)
            if displayWeight > 0 {
                weight = WeightUtility.format(firstSet.weightKg, displayUnit: weightUnit, showUnit: false)
            }
        }
        notes = entry.notes
        showNotesField = !entry.notes.isEmpty
    }

    private func ensureInitialSegment() {
        guard supportsSegments, !didEnsureInitialSegment, entry.activitySegments.isEmpty else { return }
        didEnsureInitialSegment = true
        onAddSegment?()
    }
}

private struct ActivitySegmentRow: View {
    let index: Int
    let segment: LiveWorkoutEntry.ActivitySegment
    let fields: [Exercise.TrackingField]
    let usesMetricWeight: Bool
    let onUpdateDuration: (Int) -> Void
    let onUpdateDistance: (Double) -> Void
    let onUpdateReps: (Int) -> Void
    let onUpdateWeightKg: (Double) -> Void
    let onUpdateNotes: (String) -> Void
    let onRemove: () -> Void
    let countUnitLabel: String

    @State private var durationMinutes = ""
    @State private var durationSeconds = ""
    @State private var distanceKm = ""
    @State private var reps = ""
    @State private var weight = ""
    @State private var notes = ""
    @State private var showNotesField = false

    private var weightUnitLabel: String {
        usesMetricWeight ? "kg" : "lbs"
    }

    private var visibleMetricFields: [Exercise.TrackingField] {
        fields.filter { field in
            switch field {
            case .duration, .distance, .reps, .weight:
                return true
            case .sets, .notes:
                return false
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Text("\(index + 1)")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 28, height: 28)
                    .background(Color(.tertiarySystemFill), in: Circle())
                    .foregroundStyle(.primary)

                VStack(alignment: .leading, spacing: 6) {
                    if !visibleMetricFields.isEmpty {
                        metricRows
                    }

                    if fields.contains(.notes), showNotesField || !notes.isEmpty {
                        TextField("Notes", text: $notes, axis: .vertical)
                            .lineLimit(1...3)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                            .onChange(of: notes) { _, value in onUpdateNotes(value) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if fields.contains(.notes) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showNotesField.toggle()
                        }
                    } label: {
                        Image(systemName: notes.isEmpty ? "note.text.badge.plus" : "note.text")
                            .font(.body)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(notes.isEmpty ? Color.secondary : Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(notes.isEmpty ? "Add segment notes" : "Edit segment notes")
                }

                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete segment \(index + 1)")
            }
        }
        .padding(.vertical, 3)
        .onAppear(perform: syncFields)
    }

    private var metricRows: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ForEach(Array(visibleMetricFields.prefix(2)), id: \.self) { field in
                    metricInput(for: field)
                }
            }

            let remaining = Array(visibleMetricFields.dropFirst(2))
            if !remaining.isEmpty {
                HStack(spacing: 8) {
                    ForEach(remaining, id: \.self) { field in
                        metricInput(for: field)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func metricInput(for field: Exercise.TrackingField) -> some View {
        switch field {
        case .duration:
            segmentDurationField
        case .distance:
            segmentValueField(label: "km", placeholder: "0.00", text: $distanceKm, keyboard: .decimalPad)
                .onChange(of: distanceKm) { _, value in
                    onUpdateDistance((Double(value) ?? 0) * 1000)
                }
        case .reps:
            segmentValueField(label: countUnitLabel, placeholder: "0", text: $reps)
                .onChange(of: reps) { _, value in
                    onUpdateReps(Int(value) ?? 0)
                }
        case .weight:
            segmentValueField(label: weightUnitLabel, placeholder: "0", text: $weight, keyboard: .decimalPad)
                .onChange(of: weight) { _, value in
                    let displayValue = Double(value) ?? 0
                    onUpdateWeightKg(usesMetricWeight ? displayValue : displayValue / WeightUtility.kgToLbs)
                }
        case .sets, .notes:
            EmptyView()
        }
    }

    private var segmentDurationField: some View {
        HStack(spacing: 4) {
            TextField("00", text: $durationMinutes)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(width: 30)
                .onChange(of: durationMinutes) { _, _ in updateDuration() }
            Text(":")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("00", text: $durationSeconds)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(width: 30)
                .onChange(of: durationSeconds) { _, _ in updateDuration() }
            Text("min")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
    }

    private func segmentValueField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .numberPad
    ) -> some View {
        HStack(spacing: 4) {
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.center)
                .frame(width: 42)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
    }

    private func updateDuration() {
        onUpdateDuration((Int(durationMinutes) ?? 0) * 60 + (Int(durationSeconds) ?? 0))
    }

    private func syncFields() {
        if let seconds = segment.durationSeconds {
            durationMinutes = "\(seconds / 60)"
            durationSeconds = String(format: "%02d", seconds % 60)
        }
        if let meters = segment.distanceMeters {
            distanceKm = String(format: "%.2f", meters / 1000)
        }
        if let segmentReps = segment.reps, segmentReps > 0 {
            reps = "\(segmentReps)"
        }
        if let kg = segment.weightKg, kg > 0 {
            let unit = WeightUnit(usesMetric: usesMetricWeight)
            weight = WeightUtility.format(kg, displayUnit: unit, showUnit: false)
        }
        notes = segment.notes
        showNotesField = !segment.notes.isEmpty
    }
}
