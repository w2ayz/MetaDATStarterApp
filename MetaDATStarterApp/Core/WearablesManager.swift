import MWDATCore
import SwiftUI

@MainActor
final class WearablesManager: ObservableObject {
    static let shared = WearablesManager()

    @Published var registrationState: RegistrationState = .unavailable
    @Published var devices: [DeviceIdentifier] = []
    @Published var error: Error?

    private init() {}

    func startObserving() {
        Task {
            for await state in Wearables.shared.registrationStateStream() {
                registrationState = state
                // Clear error on successful state transitions
                if state == .registered { error = nil }
            }
        }
        Task {
            for await list in Wearables.shared.devicesStream() {
                devices = list
            }
        }
    }

    func handleUrl(_ url: URL) {
        Task {
            do {
                _ = try await Wearables.shared.handleUrl(url)
            } catch {
                self.error = error
            }
        }
    }

    func register() {
        error = nil
        Task {
            do {
                try await Wearables.shared.startRegistration()
            } catch {
                self.error = error
            }
        }
    }

    func unregister() {
        error = nil
        Task {
            do {
                try await Wearables.shared.startUnregistration()
            } catch {
                self.error = error
            }
        }
    }
}
