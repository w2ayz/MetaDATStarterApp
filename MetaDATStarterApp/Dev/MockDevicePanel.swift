#if DEBUG
import SwiftUI

struct MockDevicePanel: View {
    @EnvironmentObject private var service: MockDeviceService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                toggleSection
                if service.isActive { glassesStateSection }
                helpSection
            }
            .navigationTitle("Developer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .animation(.default, value: service.isActive)
        }
    }

    // MARK: - Sections

    private var toggleSection: some View {
        Section {
            Toggle(
                "Mock Mode",
                isOn: Binding(get: { service.isEnabled }, set: { service.setEnabled($0) })
            )

            LabeledContent("Device") {
                if service.isActive {
                    Label("Simulated · \(service.isWorn ? "Worn" : "Removed")",
                          systemImage: service.isWorn ? "eyeglasses" : "eye.slash")
                        .foregroundStyle(service.isWorn ? .green : .orange)
                        .font(.subheadline)
                } else {
                    Text("None")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
        } header: {
            Text("MockDeviceKit")
        } footer: {
            Text("Simulates a paired Ray-Ban Meta device on simulator or device. Disable to use real hardware.")
        }
    }

    private var glassesStateSection: some View {
        Section("Glasses State") {
            Button {
                Task { await service.simulateDon() }
            } label: {
                Label("Don (wear glasses)", systemImage: "eyeglasses")
            }
            .disabled(service.isWorn)

            Button {
                Task { await service.simulateDoff() }
            } label: {
                Label("Doff (remove glasses)", systemImage: "eye.slash")
            }
            .disabled(!service.isWorn)
            .foregroundStyle(.orange)
        }
    }

    private var helpSection: some View {
        Section("How to switch modes") {
            VStack(alignment: .leading, spacing: 6) {
                Label("Mock mode", systemImage: "wrench.and.screwdriver")
                    .font(.subheadline.weight(.medium))
                Text("Enable above. Works on simulator and device — no glasses required.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 6) {
                Label("Real glasses", systemImage: "eyeglasses")
                    .font(.subheadline.weight(.medium))
                Text("Disable mock mode. Pair glasses via Meta AI, then register on the Wearables tab.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
    }
}
#endif
