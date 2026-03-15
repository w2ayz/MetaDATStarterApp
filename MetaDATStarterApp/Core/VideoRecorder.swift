import AVFoundation
import Photos

enum VideoRecorderError: LocalizedError {
    case setupFailed(Error)
    case saveFailed(Error)
    case photosDenied

    var errorDescription: String? {
        switch self {
        case .setupFailed(let e):  return "Recorder setup failed: \(e.localizedDescription)"
        case .saveFailed(let e):   return "Failed to save video: \(e.localizedDescription)"
        case .photosDenied:        return "Photos access denied. Enable it in Settings to save videos."
        }
    }
}

actor VideoRecorder {
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var sessionStarted = false
    private var outputURL: URL?
    private(set) var isActive = false

    func start(width: Int, height: Int) throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp4")
        outputURL = url

        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        } catch {
            throw VideoRecorderError.setupFailed(error)
        }

        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 4_000_000],
            ]
        )
        input.expectsMediaDataInRealTime = true
        writer.add(input)

        guard writer.startWriting() else {
            throw VideoRecorderError.setupFailed(
                writer.error ?? NSError(domain: "VideoRecorder", code: -1)
            )
        }

        self.writer = writer
        self.videoInput = input
        self.sessionStarted = false
        self.isActive = true
    }

    func append(_ sampleBuffer: CMSampleBuffer) {
        guard isActive,
              let input = videoInput,
              let writer = writer,
              writer.status == .writing else { return }

        if !sessionStarted {
            let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            writer.startSession(atSourceTime: pts)
            sessionStarted = true
        }

        guard input.isReadyForMoreMediaData else { return }
        input.append(sampleBuffer)
    }

    // Returns the temp file URL on success, nil if nothing was recorded.
    func stop() async -> URL? {
        guard isActive else { return nil }
        isActive = false

        guard let input = videoInput, let writer = writer else {
            reset(); return nil
        }

        input.markAsFinished()
        await writer.finishWriting()

        let url = outputURL
        reset()
        return writer.status == .completed ? url : nil
    }

    private func reset() {
        writer = nil
        videoInput = nil
        sessionStarted = false
        outputURL = nil
    }
}

// MARK: - Photos save helper

extension VideoRecorder {
    static func saveToPhotos(url: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw VideoRecorderError.photosDenied
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }
        } catch {
            throw VideoRecorderError.saveFailed(error)
        }
        try? FileManager.default.removeItem(at: url)
    }
}
