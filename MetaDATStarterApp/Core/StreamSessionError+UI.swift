import MWDATCamera

extension StreamSessionError {
    var friendlyMessage: String {
        switch self {
        case .permissionDenied:
            return "Camera permission denied.\nOpen Meta AI and grant camera access."
        case .deviceNotFound:
            return "No glasses found.\nMake sure your Ray-Ban Meta glasses are paired and nearby."
        case .deviceNotConnected:
            return "Glasses disconnected.\nMake sure they're powered on and in range."
        case .hingesClosed:
            return "Glasses are folded.\nOpen them to start the stream."
        case .timeout:
            return "Connection timed out.\nTry starting the stream again."
        case .thermalCritical:
            return "Device too hot.\nLet it cool down before streaming."
        case .videoStreamingError:
            return "Video stream error.\nTry restarting the stream."
        case .internalError:
            return "Internal error.\nTry restarting the stream."
        }
    }
}
