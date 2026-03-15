import MWDATCamera
import SwiftUI

struct StreamView: View {
    @EnvironmentObject private var stream: StreamManager
    @State private var showFullPhoto = false
    @State private var toastTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                preview
                Divider()
                controlBar
                    .padding(.horizontal)
                    .padding(.vertical, 12)
            }
            .navigationTitle("Camera")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showFullPhoto) {
                photoSheet
            }
            .alert("Recording Error", isPresented: .constant(stream.recordingError != nil), actions: {
                Button("OK") { stream.recordingError = nil }
            }, message: {
                Text(stream.recordingError?.localizedDescription ?? "")
            })
            .overlay(alignment: .bottom) { saveToast }
            .onChange(of: stream.photoSaveStatus) { status in
                guard status == .saved || (status != nil && status != .saving) else { return }
                toastTask?.cancel()
                toastTask = Task {
                    try? await Task.sleep(for: .seconds(2.5))
                    guard !Task.isCancelled else { return }
                    stream.photoSaveStatus = nil
                }
            }
        }
    }

    // MARK: - Save toast

    @ViewBuilder
    private var saveToast: some View {
        if let status = stream.photoSaveStatus {
            HStack(spacing: 8) {
                switch status {
                case .saving:
                    ProgressView().controlSize(.small).tint(.white)
                    Text("Saving…")
                case .saved:
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("Saved to Photos")
                case .failed(let msg):
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                    Text(msg).lineLimit(2)
                }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.black.opacity(0.75), in: Capsule())
            .padding(.bottom, 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(duration: 0.3), value: stream.photoSaveStatus)
        }
    }

    // MARK: - Preview

    private var preview: some View {
        ZStack {
            Color.black

            if let frame = stream.currentFrame {
                Image(uiImage: frame)
                    .resizable()
                    .scaledToFit()
            } else if let error = stream.streamError {
                streamErrorPlaceholder(error)
            } else {
                idlePlaceholder
            }

            // Badges — top corners
            VStack {
                HStack {
                    stateBadge
                    Spacer()
                    if stream.isRecording { recordingBadge }
                }
                .padding(12)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(9/16, contentMode: .fit)
        .clipped()
    }

    private var idlePlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "eyeglasses")
                .font(.system(size: 48))
            Text(stateLabel)
                .font(.subheadline)
        }
        .foregroundStyle(.white.opacity(0.5))
    }

    private func streamErrorPlaceholder(_ error: StreamSessionError) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(error.friendlyMessage)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            if error == .permissionDenied {
                Button("Grant Camera Access") {
                    stream.requestCameraPermission()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
        }
        .foregroundStyle(.white.opacity(0.85))
    }

    // MARK: - Badges

    private var stateBadge: some View {
        Text(stateLabel)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(stateBadgeColor.opacity(0.85), in: Capsule())
            .foregroundStyle(.white)
    }

    private var recordingBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(.red)
                .frame(width: 7, height: 7)
            Text("REC")
                .font(.caption2.weight(.bold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.6), in: Capsule())
        .foregroundStyle(.red)
    }

    private var stateLabel: String {
        switch stream.streamState {
        case .stopped:           return "Idle"
        case .stopping:          return "Stopping"
        case .waitingForDevice:  return "Waiting for device"
        case .starting:          return "Starting"
        case .streaming:         return "Live"
        case .paused:            return "Paused"
        @unknown default:        return "Unknown"
        }
    }

    private var stateBadgeColor: Color {
        switch stream.streamState {
        case .streaming:         return .green
        case .paused:            return .orange
        case .starting,
             .waitingForDevice:  return .blue
        default:                 return .gray
        }
    }

    // MARK: - Control bar

    private var controlBar: some View {
        HStack(spacing: 20) {
            streamToggleButton
            Spacer()
            recordButton
            captureButton
            Spacer()
            thumbnailButton
        }
    }

    private var streamToggleButton: some View {
        Group {
            if stream.isActive {
                Button(role: .destructive) {
                    stream.stop()
                } label: {
                    Label("Stop", systemImage: "stop.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else {
                Button {
                    stream.start()
                } label: {
                    Label("Start Stream", systemImage: "play.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var recordButton: some View {
        let canRecord = stream.streamState == .streaming
        return Button {
            if stream.isRecording {
                stream.stopRecording()
            } else if canRecord {
                stream.startRecording()
            } else {
                // Inform the user instead of silently dropping the tap
                stream.photoSaveStatus = .failed("Start the stream first to record.")
            }
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(canRecord ? .red : .gray, lineWidth: 3)
                    .frame(width: 40, height: 40)
                if stream.isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.red)
                        .frame(width: 16, height: 16)
                } else {
                    Circle()
                        .fill(canRecord ? .red : Color(.systemGray3))
                        .frame(width: 26, height: 26)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: stream.isRecording)
        .animation(.easeInOut(duration: 0.2), value: canRecord)
    }

    private var captureButton: some View {
        Button {
            stream.capturePhoto()
        } label: {
            Image(systemName: "camera.shutter.button.fill")
                .font(.system(size: 36))
                .foregroundStyle(stream.streamState == .streaming ? .primary : .secondary)
        }
        .disabled(stream.streamState != .streaming)
    }

    private var thumbnailButton: some View {
        Group {
            if let photo = stream.capturedPhoto {
                Button { showFullPhoto = true } label: {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                        )
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.secondary.opacity(0.15))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundStyle(.tertiary)
                    )
            }
        }
        .animation(.spring(duration: 0.3), value: stream.capturedPhoto != nil)
    }

    // MARK: - Full-size photo sheet

    private var photoSheet: some View {
        NavigationStack {
            Group {
                if let photo = stream.capturedPhoto {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFit()
                        .ignoresSafeArea(edges: .bottom)
                }
            }
            .navigationTitle("Captured Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showFullPhoto = false }
                }
            }
            .background(.black)
        }
    }
}
