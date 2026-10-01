import SwiftUI
import PhotosUI

/// Compact camera and review presentation of the food capture pipeline.
struct FoodCaptureSheetView: View {
    let cameraService: CameraService
    let isCapturing: Bool
    let cameraUnavailable: Bool
    @Binding var description: String
    @Binding var selectedPhoto: PhotosPickerItem?
    let suggestions: [FoodSuggestion]
    let onSelectSuggestion: (FoodSuggestion) -> Void
    let onCapture: () -> Void
    let onDescribe: () -> Void
    let onEnableCamera: () -> Void
    let onManualEntry: () -> Void
    let onCancel: () -> Void
    @State private var describing = false
    @FocusState private var descriptionFocused: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var previewImage: UIImage? {
        if AppLaunchArguments.shouldUseFoodCaptureFixture {
            if let path = AppLaunchArguments.foodCaptureFixturePath {
                return UIImage(contentsOfFile: path)
            }
            return UIImage(named: "AppStoreFoodCameraSample")
        }
        return AppLaunchArguments.isUITesting && AppLaunchArguments.shouldUseMockFoodAIResponses
            ? UIImage(named: "AppStoreFoodCameraSample") : nil
    }

    var body: some View {
        ZStack {
            Color.black
            if let previewImage {
                GeometryReader { geometry in
                    Image(uiImage: previewImage).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                }
            } else {
                CameraPreviewView(cameraService: cameraService)
            }
            LinearGradient(colors: [.black.opacity(0.25), .clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
            VStack(spacing: 16) {
                HStack {
                    Menu {
                        Button("Enter manually", systemImage: "square.and.pencil", action: onManualEntry)
                    } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                        .accessibilityLabel("More food options")
                    Spacer()
                    Button(action: onCancel) {
                        Image(systemName: "xmark").font(.title3.weight(.semibold))
                            .frame(width: 44, height: 44).contentShape(.rect)
                    }.buttonStyle(.plain).accessibilityLabel("Close camera").accessibilityIdentifier("compactFoodClose")
                }
                Spacer(minLength: 0)
                if cameraUnavailable {
                    VStack(spacing: 10) {
                        Text("Camera unavailable").font(.headline)
                        Button("Enable camera", action: onEnableCamera).buttonStyle(.glass)
                    }
                    Spacer(minLength: 0)
                }
                if describing {
                    HStack(spacing: 10) {
                        TextField("Describe your meal", text: $description,
                                  prompt: Text("Describe your meal").foregroundStyle(.white.opacity(0.8)),
                                  axis: .vertical)
                            .font(.system(.body, design: .rounded))
                            .lineLimit(1...3).focused($descriptionFocused)
                            .accessibilityIdentifier("compactFoodDescription")
                        Button { descriptionFocused = false; onDescribe() } label: {
                            Image(systemName: "arrow.up").frame(width: 32, height: 32)
                        }.buttonStyle(.glassProminent)
                            .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityLabel("Analyze meal").accessibilityIdentifier("compactFoodAnalyze")
                        Button { describing = false; descriptionFocused = false } label: {
                            Image(systemName: "xmark").frame(width: 32, height: 44)
                        }.accessibilityLabel("Back to camera")
                    }
                    .padding(12)
                    .background {
                        if reduceTransparency {
                            Capsule().fill(Color(white: 0.16))
                        }
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .environment(\.colorScheme, .dark)
                } else {
                    if !suggestions.isEmpty {
                        recentMealPills
                    }
                    HStack {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Image(systemName: "photo.on.rectangle").font(.title3).frame(width: 40, height: 40)
                        }.buttonStyle(.glass).accessibilityLabel("Choose meal photo")
                        Spacer()
                        Button(action: onCapture) {
                            Circle().fill(.white).frame(width: 54, height: 54).padding(5)
                                .overlay { Circle().stroke(.white, lineWidth: 2) }
                                .overlay { if isCapturing { ProgressView().tint(.black) } }
                        }.buttonStyle(.plain).disabled(isCapturing || cameraUnavailable)
                            .accessibilityLabel("Take food photo").accessibilityIdentifier("compactFoodCapture")
                        Spacer()
                        Button { describing = true; descriptionFocused = true } label: {
                            Image(systemName: "text.bubble").font(.title3).frame(width: 40, height: 40)
                        }.buttonStyle(.glass).accessibilityLabel("Describe food")
                    }
                }
            }.padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 36)
                .foregroundStyle(.white).tint(.white)
        }.ignoresSafeArea(.container)
    }

    private var recentMealPills: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 4) {
                HStack(spacing: 8) {
                ForEach(suggestions) { suggestion in
                    Button {
                        descriptionFocused = false
                        onSelectSuggestion(suggestion)
                    } label: {
                        HStack(spacing: 6) {
                            Text(suggestion.emoji).accessibilityHidden(true)
                            Text(suggestion.title)
                                .font(.system(.callout, design: .rounded, weight: .semibold))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(minHeight: 28)
                        .frame(maxWidth: 220, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .disabled(isCapturing)
                    .accessibilityLabel(suggestion.title)
                    .accessibilityValue(suggestion.detail)
                    .accessibilityHint("Review this meal before saving")
                }
            }
                .padding(.vertical, 4)
            }
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("compactFoodSuggestions")
    }

}

struct FoodCaptureSheetReview: View {
    let image: UIImage?
    let suggestion: SuggestedFoodEntry?
    let suggestionRevision: Int
    let enabledMacros: Set<MacroType>
    let isAnalyzing: Bool
    let isSaving: Bool
    let isRefining: Bool
    let error: String?
    let onRetry: () -> Void
    let onRetake: () -> Void
    let onClose: () -> Void
    let onManualEntry: () -> Void
    let onRefine: (String, SuggestedFoodEntry) -> Void
    let onSave: (SuggestedFoodEntry, [String]) -> Void
    private enum Field: Hashable { case name, correction }
    @FocusState private var focusedField: Field?
    @State private var name = ""
    @State private var portions = 1.0
    @State private var details = false
    @State private var correcting = false
    @State private var correction = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    Button(action: onRetake) {
                        Group {
                            if let image { Image(uiImage: image).resizable().scaledToFill() }
                            else { Image(systemName: "fork.knife").font(.title).frame(maxWidth: .infinity, maxHeight: .infinity).background(.quaternary) }
                        }.frame(width: 72, height: 72).clipShape(.rect(corners: .concentric(minimum: 12)))
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "arrow.counterclockwise").font(.caption.bold()).padding(5)
                                    .background(.regularMaterial, in: .circle).padding(3)
                            }
                    }.buttonStyle(.plain).accessibilityLabel("Retake photo").accessibilityIdentifier("compactFoodRetake").disabled(isSaving)
                    VStack(alignment: .leading, spacing: 5) {
                        if let suggestion {
                            TextField("Meal name", text: $name).font(.headline).accessibilityIdentifier("compactFoodName").disabled(isRefining || isSaving)
                                .focused($focusedField, equals: .name)
                                .submitLabel(.done).onSubmit { focusedField = nil }
                            Text("≈ \(Int((Double(suggestion.calories) * portions).rounded())) kcal")
                                .font(.title2.weight(.semibold)).contentTransition(.numericText())
                        } else { Text(isAnalyzing ? "Estimating…" : "Your meal").font(.headline) }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 5)
                    Button(action: onClose) {
                        Image(systemName: "xmark").font(.body.weight(.semibold)).foregroundStyle(.secondary)
                            .frame(width: 44, height: 44).contentShape(.rect)
                    }.buttonStyle(.plain).accessibilityLabel("Close").accessibilityIdentifier("compactFoodClose")
                }
                if let error {
                    Text(error).font(.subheadline).foregroundStyle(.red).accessibilityIdentifier("compactFoodError")
                    if suggestion == nil {
                        HStack { Button("Try again", action: onRetry); Spacer(); Button("Enter manually", action: onManualEntry) }
                    }
                }
                if let suggestion {
                    HStack {
                        Text(portions == 1 ? (suggestion.servingSize ?? "1 portion") : "\(portions.formatted()) × \(suggestion.servingSize ?? "portion")")
                            .font(.subheadline).monospacedDigit()
                        Spacer()
                        Stepper("Portion multiplier", value: $portions, in: 0.5...5, step: 0.5).labelsHidden().accessibilityIdentifier("compactFoodPortion").disabled(isRefining || isSaving)
                    }
                    DisclosureGroup("Nutrition details", isExpanded: $details) {
                        VStack(spacing: 8) {
                            macro("Protein", grams: suggestion.proteinGrams, color: MacroType.protein.color)
                            macro("Carbs", grams: suggestion.carbsGrams, color: MacroType.carbs.color)
                            macro("Fat", grams: suggestion.fatGrams, color: MacroType.fat.color)
                            if enabledMacros.contains(.fiber) { macro("Fibre", grams: suggestion.fiberGrams, color: MacroType.fiber.color) }
                            if enabledMacros.contains(.sugar) { macro("Sugar", grams: suggestion.sugarGrams, color: MacroType.sugar.color) }
                        }.padding(.top, 8)
                    }.font(.subheadline).foregroundStyle(.secondary)
                    if correcting {
                        HStack {
                            TextField("What should change?", text: $correction, axis: .vertical).lineLimit(1...3).accessibilityIdentifier("compactFoodCorrection")
                                .focused($focusedField, equals: .correction)
                                .submitLabel(.send).onSubmit { refine(suggestion) }
                            Button { refine(suggestion) } label: {
                                if isRefining { ProgressView() } else { Image(systemName: "arrow.up") }
                            }.disabled(correction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRefining)
                                .accessibilityLabel("Update estimate")
                        }.padding(12).background(.quaternary, in: .rect(corners: .concentric(minimum: 12)))
                    } else {
                        Button("Adjust estimate") { correcting = true; focusedField = .correction }.font(.subheadline)
                    }
                    Button {
                        focusedField = nil
                        onSave(suggestion.adjustedForCapture(name: name, multiplier: portions),
                            (name != suggestion.name ? ["name"] : []) + (portions != 1 ? ["portion"] : []))
                    } label: {
                        HStack { if isSaving { ProgressView() }; Text("Save meal").font(.headline) }
                            .frame(maxWidth: .infinity).padding(.vertical, 9)
                    }.buttonStyle(.glassProminent).tint(.accentColor)
                        .disabled(isSaving || isRefining || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("compactFoodSave")
                } else if isAnalyzing {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 30)
                }
            }.padding(.horizontal, 22).padding(.top, 28).padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: suggestionRevision, initial: true) { _, _ in
            if let suggestion { name = suggestion.name; portions = 1; correcting = false; correction = "" }
        }
    }

    private func refine(_ suggestion: SuggestedFoodEntry) {
        guard !isRefining, !isSaving,
              !correction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        focusedField = nil
        onRefine(correction, suggestion.adjustedForCapture(name: name, multiplier: portions))
    }

    private func macro(_ title: String, grams: Double?, color: Color) -> some View {
        HStack {
            Label {
                Text(title).foregroundStyle(.primary)
            } icon: {
                Circle().fill(color).frame(width: 8, height: 8)
            }
            Spacer()
            Text(grams.map { "\(($0 * portions).formatted(.number.precision(.fractionLength(0...1)))) g" } ?? "Not estimated")
                .foregroundStyle(.primary)
        }
    }
}

extension SuggestedFoodEntry {
    func adjustedForCapture(name: String, multiplier: Double) -> SuggestedFoodEntry {
        SuggestedFoodEntry(
            id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            calories: Int((Double(calories) * multiplier).rounded()),
            proteinGrams: proteinGrams * multiplier, carbsGrams: carbsGrams * multiplier, fatGrams: fatGrams * multiplier,
            fiberGrams: fiberGrams.map { $0 * multiplier }, sugarGrams: sugarGrams.map { $0 * multiplier },
            servingSize: multiplier == 1 ? servingSize : "\(multiplier.formatted()) × \(servingSize ?? "portion")", emoji: emoji,
            loggedAtDateString: loggedAtDateString, loggedAtTime: loggedAtTime,
            components: components.map {
                SuggestedFoodComponent(id: $0.id, displayName: $0.displayName, role: $0.role,
                    quantity: $0.quantity.map { $0 * multiplier }, unit: $0.unit,
                    calories: Int((Double($0.calories) * multiplier).rounded()), proteinGrams: $0.proteinGrams * multiplier,
                    carbsGrams: $0.carbsGrams * multiplier, fatGrams: $0.fatGrams * multiplier,
                    fiberGrams: $0.fiberGrams.map { $0 * multiplier }, sugarGrams: $0.sugarGrams.map { $0 * multiplier }, confidence: $0.confidence)
            }, mealKind: mealKind, notes: notes, confidence: confidence, schemaVersion: schemaVersion
        )
    }
}
