import SwiftUI

struct MainView: View {
    #if DEBUG
    @EnvironmentObject private var mockService: MockDeviceService
    @State private var showDevPanel = false
    #endif

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView {
                RegistrationView()
                    .tabItem { Label("Wearables", systemImage: "eyeglasses") }

                StreamView()
                    .tabItem { Label("Camera", systemImage: "camera") }
            }

            #if DEBUG
            devButton
            #endif
        }
        #if DEBUG
        .sheet(isPresented: $showDevPanel) {
            MockDevicePanel()
                .environmentObject(mockService)
        }
        #endif
    }

    // MARK: - Debug

    #if DEBUG
    private var devButton: some View {
        Button { showDevPanel = true } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 15))
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
                    .shadow(radius: 2)

                if mockService.isActive {
                    Circle()
                        .fill(.orange)
                        .frame(width: 9, height: 9)
                        .offset(x: 2, y: -2)
                }
            }
        }
        .padding(.trailing, 16)
        .padding(.bottom, 56) // clears tab bar
    }
    #endif
}
