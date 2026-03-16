import CoreImage
import MWDATCamera
import MWDATCore
import OSLog
import Photos
import SwiftUI

private let photoLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MetaDATStarterApp", category: "PhotoCapture")
private let streamLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MetaDATStarterApp", category: "StreamManager")

enum PhotoSaveStatus: Equatable {
    case saving
    case saved
    case failed(String)
}

@MainActor
final class StreamManager: ObservableObject {
    @Published var streamState: StreamSessionState = .stopped
    @Published var currentFrame: UIImage?
    @Published var capturedPhoto: UIImage?
    @Published var isRecording = false
    @Published var recordingError: Error?
    @Published var photoSaveStatus: PhotoSaveStatus?
    @Published var streamError: StreamSessionError?

    private var session: StreamSession?
    private var stateToken: Any?
    private var frameToken: Any?
    private var photoToken: Any?
    private var errorToken: Any?
    private var startTimeoutTask: Task<Void, Never>?

    private static let tsFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
    private func ts() -> String { Self.tsFormatter.string(from: Date()) }

    private let recorder = VideoRecorder()
    private let ciContext = CIContext()

    var isActive: Bool {
        switch streamState {
        case .streaming, .starting, .waitingForDevice, .paused: return true
        default: return false
        }
    }

    func start() {
        guard !isActive else { return }
        streamError = nil
        Task { await startChecked() }
    }

    private func startChecked() async {
        // Check DAT camera permission — request inline if not yet granted (matches Meta sample flow).
        do {
            var status = try await Wearables.shared.checkPermissionStatus(.camera)
            if status != .granted {
                streamLogger.info("DAT camera permission not granted (\(String(describing: status))) — requesting…")
                status = try await Wearables.shared.requestPermission(.camera)
            }
            if status == .denied {
                streamLogger.error("DAT camera permission denied after request")
                streamError = .permissionDenied
                return
            }
            streamLogger.info("DAT camera permission: \(String(describing: status))")
        } catch {
            streamLogger.error("Permission check/request threw: \(error.localizedDescription)")
            // Non-fatal: proceed and let errorPublisher surface the problem
        }

        let config = StreamSessionConfig(videoCodec: .raw, resolution: .medium, frameRate: 24)
        let session = StreamSession(
            streamSessionConfig: config,
            deviceSelector: AutoDeviceSelector(wearables: Wearables.shared)
        )
        self.session = session

        stateToken = session.statePublisher.listen { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self else { return }
                streamLogger.info("[\(self.ts())] stream state → \(String(describing: state))")
                self.streamState = state

                switch state {
                case .starting, .waitingForDevice:
                    // Arm timeout only on first entry to starting; waitingForDevice extends the same window
                    if self.startTimeoutTask == nil {
                        self.startTimeoutTask = Task { @MainActor [weak self] in
                            try? await Task.sleep(for: .seconds(30))
                            guard !Task.isCancelled, let self else { return }
                            // Guard against double-stop: only act if still in a pre-streaming state
                            guard self.streamState == .starting || self.streamState == .waitingForDevice else { return }
                            streamLogger.error("[\(self.ts())] start timeout — no streaming after 10s, stopping")
                            self.streamError = .timeout
                            self.stop()
                        }
                    }
                case .streaming:
                    self.startTimeoutTask?.cancel()
                    self.startTimeoutTask = nil
                case .stopped, .stopping:
                    self.startTimeoutTask?.cancel()
                    self.startTimeoutTask = nil
                default:
                    break
                }
            }
        }
        frameToken = session.videoFramePublisher.listen { [weak self] frame in
            guard let self else { return }
            let image = frame.makeUIImage() ?? self.makeUIImageFallback(from: frame)
            guard let image else {
                streamLogger.error("videoFramePublisher: failed to decode frame (makeUIImage + fallback both nil)")
                return
            }
            Task { @MainActor in self.currentFrame = image }
            Task { await self.recorder.append(frame.sampleBuffer) }
        }
        photoToken = session.photoDataPublisher.listen { [weak self] data in
            photoLogger.info("Photo data received: \(data.data.count) bytes, format: \(String(describing: data.format))")
            guard let image = UIImage(data: data.data) else {
                photoLogger.error("Failed to decode photo data into UIImage")
                return
            }
            Task { @MainActor in
                self?.capturedPhoto = image
                self?.persistPhoto(image)
            }
        }
        errorToken = session.errorPublisher.listen { [weak self] error in
            streamLogger.error("Stream error: \(String(describing: error))")
            Task { @MainActor in self?.streamError = error }
        }

        streamLogger.info("Starting stream session (codec: raw, resolution: medium, fps: 24)")
        await session.start()
    }

    func stop() {
        guard session != nil else { return }  // prevent double-stop

        startTimeoutTask?.cancel()
        startTimeoutTask = nil

        stopRecording()
        currentFrame = nil

        // Drop frame/photo tokens immediately — no new frames or photos needed.
        frameToken = nil
        photoToken = nil

        // Capture session + state/error tokens so they stay alive inside the Task.
        // The stateToken must remain subscribed so the SDK's own .stopping → .stopped
        // transitions reach us and drive the button/badge back to idle.
        let capturedSession = session
        let capturedStateToken = stateToken
        let capturedErrorToken = errorToken

        session = nil
        stateToken = nil
        errorToken = nil

        streamLogger.info("Stopping stream session…")
        Task {
            _ = capturedStateToken   // keeps subscription alive during stop
            _ = capturedErrorToken
            await capturedSession?.stop()
            streamLogger.info("Stream session stopped")
            // Tokens released here, after .stopped state has been emitted
        }
    }

    func capturePhoto() {
        session?.capturePhoto(format: .jpeg)
    }

    /// Called when makeUIImage() returns nil — tries CVPixelBuffer → CIImage → UIImage.
    nonisolated private func makeUIImageFallback(from frame: VideoFrame) -> UIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(frame.sampleBuffer) else {
            return nil
        }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    /// Requests DAT camera permission — opens Meta AI for the user to approve.
    func requestCameraPermission() {
        Task {
            do {
                let status = try await Wearables.shared.requestPermission(.camera)
                streamLogger.info("Camera permission request result: \(String(describing: status))")
                if status == .granted { streamError = nil }
            } catch {
                streamLogger.error("requestPermission threw: \(error.localizedDescription)")
            }
        }
    }

    private func persistPhoto(_ image: UIImage) {
        photoSaveStatus = .saving
        Task {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                let msg = "Photos permission denied (status: \(status.rawValue))"
                photoLogger.error("\(msg)")
                photoSaveStatus = .failed("Photos access denied. Enable it in Settings.")
                return
            }
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
                photoLogger.info("Photo saved to library successfully")
                photoSaveStatus = .saved
            } catch {
                photoLogger.error("Photo save failed: \(error.localizedDescription)")
                photoSaveStatus = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: - Recording

    func startRecording() {
        guard streamState == .streaming, !isRecording else { return }
        recordingError = nil
        let config = session?.streamSessionConfig
        let size = (config?.resolution ?? .medium).videoFrameSize
        Task {
            do {
                try await recorder.start(width: Int(size.width), height: Int(size.height))
                isRecording = true
            } catch {
                recordingError = error
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        Task {
            guard let url = await recorder.stop() else { return }
            do {
                try await VideoRecorder.saveToPhotos(url: url)
            } catch {
                recordingError = error
            }
        }
    }
}
