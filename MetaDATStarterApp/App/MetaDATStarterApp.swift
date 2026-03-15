import MWDATCore
import SwiftUI

@main
struct MetaDATStarterApp: App {
    private let wearables = WearablesManager.shared
    private let stream = StreamManager()

    init() {
        do {
            try Wearables.configure()
        } catch {
            assertionFailure("Wearables SDK configuration failed: \(error)")
        }
        wearables.startObserving()

        #if DEBUG
        Task { await MockDeviceService.shared.activateIfEnabled() }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(wearables)
                .environmentObject(stream)
                #if DEBUG
                .environmentObject(MockDeviceService.shared)
                #endif
                .onOpenURL { url in wearables.handleUrl(url) }
        }
    }
}
