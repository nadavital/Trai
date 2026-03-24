//
//  ChatCameraComponents.swift
//  Trai
//
//  Camera view and image preview for chat
//

import SwiftUI

// MARK: - Chat Camera View

struct ChatCameraView: View {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (UIImage) -> Void

    @State private var cameraService = CameraService()

    var body: some View {
        NavigationStack {
            ZStack {
                CameraPreviewView(cameraService: cameraService)
                    .ignoresSafeArea()

                VStack {
                    Spacer()

                    Button {
                        Task {
                            if let image = await cameraService.capturePhoto() {
                                HapticManager.mediumTap()
                                onCapture(image)
                                dismiss()
                            }
                        }
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
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
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
        }
    }
}

// MARK: - Image Preview View

struct ImagePreviewView: View {
    let image: UIImage
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .gesture(
                        MagnifyGesture()
                            .onChanged { value in
                                scale = lastScale * value.magnification
                            }
                            .onEnded { _ in
                                lastScale = scale
                                if scale < 1.0 {
                                    withAnimation(.spring) {
                                        scale = 1.0
                                        lastScale = 1.0
                                    }
                                }
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring) {
                            if scale > 1.0 {
                                scale = 1.0
                                lastScale = 1.0
                            } else {
                                scale = 2.0
                                lastScale = 2.0
                            }
                        }
                    }
            }
            .background(.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") {
                        onDismiss()
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.white)
                }
            }
        }
    }
}
