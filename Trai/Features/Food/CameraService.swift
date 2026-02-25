//
//  CameraService.swift
//  Trai
//
//  Camera capture service and preview components
//

import SwiftUI
import AVFoundation

// MARK: - Camera Preview View

struct CameraPreviewView: UIViewRepresentable {
    let cameraService: CameraService

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.backgroundColor = .black
        view.cameraService = cameraService
        cameraService.setupPreviewLayer(in: view)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.updatePreviewFrame()
    }
}

/// Custom UIView that updates preview layer frame on layout
class CameraPreviewUIView: UIView {
    weak var cameraService: CameraService?

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
    private var photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var photoContinuation: CheckedContinuation<UIImage?, Never>?
    private var isConfigured = false
    private var startSessionTask: Task<Bool, Never>?

    var isAuthorized = false
    var isSessionReady = false

    func requestPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        default:
            isAuthorized = false
        }

        guard isAuthorized else {
            stopSession()
            return
        }

        await ensureSessionRunning()
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

    private func ensureSessionRunning() async {
        guard configureSessionIfNeeded() else {
            isSessionReady = false
            return
        }

        if captureSession.isRunning {
            isSessionReady = true
            return
        }

        if let existingStartTask = startSessionTask {
            isSessionReady = await existingStartTask.value
            return
        }

        let session = captureSession
        let task = Task.detached(priority: .userInitiated) { () -> Bool in
            if !session.isRunning {
                session.startRunning()
            }
            return session.isRunning
        }
        startSessionTask = task

        let didStart = await task.value
        startSessionTask = nil
        isSessionReady = didStart
    }

    func setupPreviewLayer(in view: UIView) {
        previewLayer?.removeFromSuperlayer()

        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        layer.connection?.videoRotationAngle = 90

        view.layer.addSublayer(layer)
        previewLayer = layer
    }

    func capturePhoto() async -> UIImage? {
        guard isAuthorized else { return nil }

        if !isSessionReady || !captureSession.isRunning {
            await ensureSessionRunning()
        }
        guard isSessionReady else { return nil }
        guard photoContinuation == nil else { return nil }

        return await withCheckedContinuation { continuation in
            self.photoContinuation = continuation

            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func stopSession() {
        startSessionTask?.cancel()
        startSessionTask = nil

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
