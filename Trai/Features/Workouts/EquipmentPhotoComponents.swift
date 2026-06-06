//
//  EquipmentPhotoComponents.swift
//  Trai
//
//  Camera and analysis components for identifying exercises and equipment
//

import SwiftUI

// MARK: - Equipment Camera View

struct EquipmentCameraView: View {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (Data) -> Void

    @State private var cameraService = CameraService()

    var body: some View {
        NavigationStack {
            ZStack {
                // Camera preview
                CameraPreviewView(cameraService: cameraService)
                    .ignoresSafeArea()

                // Overlay UI
                VStack {
                    Spacer()

                    // Instructions
                    Text("Point at an exercise or machine")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.6), in: .capsule)
                        .padding(.bottom, 20)

                    // Capture button
                    Button {
                        capturePhoto()
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(.white, lineWidth: 4)
                                .frame(width: 72, height: 72)

                            Circle()
                                .fill(.white)
                                .frame(width: 60, height: 60)
                        }
                    }
                    .disabled(!cameraService.isSessionReady)
                    .opacity(cameraService.isSessionReady ? 1 : 0.55)
                    .padding(.bottom, 40)
                }
            }
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .task {
                await cameraService.requestPermission()
            }
            .onDisappear {
                cameraService.stopSession()
            }
        }
    }

    private func capturePhoto() {
        Task {
            if let image = await cameraService.capturePhoto(),
               let imageData = image.jpegData(compressionQuality: 0.8) {
                onCapture(imageData)
            }
        }
    }
}

// MARK: - Exercise Photo Analysis Sheet

struct EquipmentAnalysisSheet: View {
    @Environment(\.dismiss) private var dismiss
    let analysis: ExercisePhotoAnalysis
    let onSelectExercise: (ExercisePhotoAnalysis.SuggestedExercise, String?) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Photo analysis info card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "camera.viewfinder")
                                .font(.title2)
                                .foregroundStyle(.accent)

                            Text(analysis.equipmentName)
                                .font(.title2)
                                .bold()
                        }

                        Text(analysis.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)

                        if let tips = analysis.tips {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.subheadline)

                                Text(tips)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding()
                            .background(Color.yellow.opacity(0.1))
                            .clipShape(.rect(cornerRadius: 12))
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(.rect(cornerRadius: 16))

                    // Suggested exercises
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add to Your Library")
                            .font(.headline)

                        ForEach(analysis.suggestedExercises) { exercise in
                            Button {
                                onSelectExercise(exercise, analysis.equipmentName)
                                dismiss()
                            } label: {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(exercise.name)
                                            .font(.body)
                                            .fontWeight(.medium)

                                        Text(exerciseLabel(for: exercise))
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(Color.accentColor.opacity(0.2))
                                            .clipShape(.capsule)

                                        if let howTo = exercise.howTo, !howTo.isEmpty {
                                            Text(howTo)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .multilineTextAlignment(.leading)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.accent)
                                }
                                .padding()
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(.rect(cornerRadius: 12))
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Exercise Identified")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func exerciseLabel(for exercise: ExercisePhotoAnalysis.SuggestedExercise) -> String {
        exercise.resolvedDisplayLabel(equipmentName: analysis.equipmentName)
    }
}
