//
//  CameraService.swift
//  Trai
//
//  Shared camera capture service and preview components
//

import SwiftUI
import AVFoundation

// MARK: - Camera Preview View

struct CameraPreviewView: UIViewRepresentable {
    let cameraService: CameraService

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.backgroundColor = .black
        cameraService.setupPreviewLayer(in: view)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.updatePreviewFrame()
    }
}

class CameraPreviewUIView: UIView {
    override func layoutSubviews() {
        super.layoutSubviews()
        updatePreviewFrame()
    }

    func updatePreviewFrame() {
        layer.sublayers?.forEach { sublayer in
            if sublayer is AVCaptureVideoPreviewLayer {
                sublayer.frame = bounds
            }
        }
    }
}

// MARK: - Camera Service

@Observable
@MainActor
final class CameraService: NSObject {
    private let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var photoContinuation: CheckedContinuation<UIImage?, Never>?
    private var isConfigured = false

    var isAuthorized = false
    var isSessionReady = false

    func requestPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            isAuthorized = true
            _ = await startSessionIfNeeded()
        case .notDetermined:
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
            if isAuthorized {
                _ = await startSessionIfNeeded()
            }
        default:
            isAuthorized = false
            isSessionReady = false
        }
    }

    func setupPreviewLayer(in view: UIView) {
        previewLayer?.removeFromSuperlayer()

        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        if let connection = layer.connection,
           connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }

        view.layer.addSublayer(layer)
        previewLayer = layer
    }

    func capturePhoto() async -> UIImage? {
        guard isAuthorized else { return nil }
        guard await startSessionIfNeeded() else { return nil }
        guard photoContinuation == nil else { return nil }

        return await withCheckedContinuation { continuation in
            self.photoContinuation = continuation

            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func stopSession() {
        guard captureSession.isRunning else {
            isSessionReady = false
            return
        }

        let session = captureSession
        Task.detached(priority: .utility) {
            session.stopRunning()
        }

        isSessionReady = false
    }

    @discardableResult
    private func startSessionIfNeeded() async -> Bool {
        guard configureSessionIfNeeded() else {
            isSessionReady = false
            return false
        }

        if captureSession.isRunning {
            isSessionReady = true
            return true
        }

        let session = captureSession
        let didStart = await Task.detached(priority: .userInitiated) { () -> Bool in
            if !session.isRunning {
                session.startRunning()
            }
            return session.isRunning
        }.value

        isSessionReady = didStart
        return didStart
    }

    private func configureSessionIfNeeded() -> Bool {
        guard !isConfigured else { return true }

        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        captureSession.sessionPreset = .photo

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            return false
        }

        let hasVideoInput = captureSession.inputs.contains { sessionInput in
            guard let videoInput = sessionInput as? AVCaptureDeviceInput else { return false }
            return videoInput.device.hasMediaType(.video)
        }
        if !hasVideoInput {
            guard captureSession.canAddInput(input) else { return false }
            captureSession.addInput(input)
        }

        let hasPhotoOutput = captureSession.outputs.contains { output in
            output === photoOutput
        }
        if !hasPhotoOutput {
            guard captureSession.canAddOutput(photoOutput) else { return false }
            captureSession.addOutput(photoOutput)
        }

        isConfigured = true
        return true
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        Task { @MainActor in
            if error != nil {
                photoContinuation?.resume(returning: nil)
                photoContinuation = nil
                return
            }

            guard let data = photo.fileDataRepresentation(),
                  let image = UIImage(data: data) else {
                photoContinuation?.resume(returning: nil)
                photoContinuation = nil
                return
            }

            photoContinuation?.resume(returning: image)
            photoContinuation = nil
        }
    }
}
