import MWDATCamera

extension StreamSessionError {
    var friendlyMessage: String {
        switch self {
        case .permissionDenied:
            return "Camera permission denied. Open Meta AI and grant camera access."
        case .deviceNotFound:
            return "No glasses found. Make sure your Ray-Ban Meta glasses are paired and nearby."
        case .deviceNotConnected:
            return "Glasses disconnected. Make sure they're powered on and in range."
        case .hingesClosed:
            return "Glasses are folded. Open them to start the stream."
        case .timeout:
            return "No active glasses detected. Make sure they're on, unfolded, and in range, then try again."
        case .thermalCritical:
            return "Device too hot. Let it cool down before streaming."
        case .videoStreamingError:
            return "Video stream error. Try restarting the stream."
        case .internalError:
            return "Internal error. Try restarting the stream."
        @unknown default:
            return "An unexpected error occurred. Try restarting the stream."
        }
    }
}
