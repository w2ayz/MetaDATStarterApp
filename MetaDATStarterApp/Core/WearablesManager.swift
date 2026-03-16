import MWDATCore
import SwiftUI

@MainActor
final class WearablesManager: ObservableObject {
    static let shared = WearablesManager()

    @Published var registrationState: RegistrationState = .unavailable
    @Published var devices: [DeviceIdentifier] = []
    @Published var hasActiveDevice: Bool = false
    @Published var error: Error?

    private var observingTasks: [Task<Void, Never>] = []

    private init() {}

    func startObserving() {
        guard observingTasks.isEmpty else { return }  // prevent double-start
        observingTasks = [
            Task {
                for await state in Wearables.shared.registrationStateStream() {
                    registrationState = state
                    if state == .registered { error = nil }
                }
            },
            Task {
                for await list in Wearables.shared.devicesStream() {
                    devices = list
                    hasActiveDevice = !list.isEmpty
                }
            }
        ]
    }

    func stopObserving() {
        observingTasks.forEach { $0.cancel() }
        observingTasks = []
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
