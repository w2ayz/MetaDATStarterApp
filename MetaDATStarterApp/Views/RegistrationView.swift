import MWDATCore
import SwiftUI

struct RegistrationView: View {
    @EnvironmentObject private var wearables: WearablesManager

    var body: some View {
        NavigationStack {
            List {
                statusSection
                if let error = wearables.error { errorSection(error) }
                actionsSection
                if !wearables.devices.isEmpty { devicesSection }
            }
            .navigationTitle("Wearables")
            .animation(.default, value: wearables.registrationState)
            .animation(.default, value: wearables.error != nil)
        }
    }

    // MARK: - Sections

    private var statusSection: some View {
        Section("Status") {
            HStack(spacing: 12) {
                stateIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text(stateLabel)
                        .font(.body)
                    Text(stateDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func errorSection(_ error: Error) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("Registration failed", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.subheadline.weight(.medium))
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Retry") { wearables.register() }
                    .font(.subheadline.weight(.medium))
            }
            .padding(.vertical, 4)
        }
    }

    private var actionsSection: some View {
        Section {
            Button {
                wearables.register()
            } label: {
                HStack {
                    Text("Register with Meta AI")
                    Spacer()
                    if wearables.registrationState == .registering {
                        ProgressView().controlSize(.small)
                    }
                }
            }
            .disabled(wearables.registrationState != .available)

            Button("Unregister", role: .destructive) {
                wearables.unregister()
            }
            .disabled(wearables.registrationState != .registered)
        } header: {
            Text("Actions")
        } footer: {
            if wearables.registrationState == .registering {
                Text("Waiting for Meta AI callback…")
                    .font(.caption)
            }
        }
    }

    private var devicesSection: some View {
        Section("Connected Devices") {
            ForEach(wearables.devices, id: \.self) { device in
                HStack(spacing: 10) {
                    Image(systemName: "eyeglasses")
                        .foregroundStyle(.secondary)
                    Text(device)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }
        }
    }

    // MARK: - State presentation helpers

    @ViewBuilder
    private var stateIcon: some View {
        switch wearables.registrationState {
        case .registered:
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
        case .registering:
            ProgressView()
                .controlSize(.regular)
        case .unavailable, .available:
            Image(systemName: "circle.slash")
                .font(.title2)
                .foregroundStyle(.secondary)
        @unknown default:
            Image(systemName: "questionmark.circle")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }

    private var stateLabel: String {
        switch wearables.registrationState {
        case .registered:   return "Registered"
        case .registering:  return "Registering…"
        case .available:    return "Not Registered"
        case .unavailable:  return "Unavailable"
        @unknown default:   return "Unknown"
        }
    }

    private var stateDescription: String {
        switch wearables.registrationState {
        case .registered:   return "Your app is authorized to access Meta glasses."
        case .registering:  return "Complete authorization in the Meta AI app."
        case .available:    return "Register to enable camera access."
        case .unavailable:  return "SDK not available. Ensure Meta AI is installed."
        @unknown default:   return ""
        }
    }
}
