#if DEBUG
import MWDATMockDevice
import SwiftUI

/// Wraps MockDeviceKit to simulate a paired Ray-Ban Meta device during development.
///
/// ## Switching between mock and real device
///
/// **Mock mode** (no physical glasses required — simulator or device):
///   1. Tap the wrench icon (bottom-right corner of the app) to open the Developer panel.
///   2. Enable "Mock Mode". A simulated Ray-Ban Meta device is paired and made available immediately.
///   3. The setting persists across launches.
///
/// **Real device mode** (default):
///   1. Open the Developer panel and disable "Mock Mode" (or leave it off — it defaults to off).
///   2. Pair your Ray-Ban Meta glasses via the Meta AI companion app.
///   3. Complete the registration flow on the Wearables tab.
///
/// This file is compiled only in DEBUG builds and is excluded from release/TestFlight.
@MainActor
final class MockDeviceService: ObservableObject {
    static let shared = MockDeviceService()

    private static let enabledKey = "dev.mockModeEnabled"

    @Published private(set) var isEnabled: Bool
    @Published private(set) var isActive = false
    @Published private(set) var isWorn = false

    private var mockDevice: MockRaybanMeta?

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
    }

    // MARK: - Toggle

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
        Task { enabled ? await activate() : await deactivate() }
    }

    // MARK: - App launch

    /// Restores mock mode if it was enabled in a previous session.
    func activateIfEnabled() async {
        guard isEnabled else { return }
        await activate()
    }

    // MARK: - Simulate wearing

    func simulateDon() async {
        await mockDevice?.don()
        isWorn = true
    }

    func simulateDoff() async {
        await mockDevice?.doff()
        isWorn = false
    }

    // MARK: - Private

    private func activate() async {
        guard mockDevice == nil else { return }
        let device = MockDeviceKit.shared.pairRaybanMeta()
        await device.powerOn()
        await device.unfold()
        await device.don()
        mockDevice = device
        isActive = true
        isWorn = true
    }

    private func deactivate() async {
        guard let device = mockDevice else { return }
        await device.doff()
        await device.fold()
        await device.powerOff()
        MockDeviceKit.shared.unpairDevice(device)
        mockDevice = nil
        isActive = false
        isWorn = false
    }
}
#endif
