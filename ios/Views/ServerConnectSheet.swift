import SwiftUI

public struct ServerConnectSheet: View {
    @ObservedObject var api = StoryTellerAPIService.shared
    @State private var inputHost: String = ""
    @State private var isTesting: Bool = false
    @State private var testResult: String?
    @Environment(\.dismiss) var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                // Liquid Mesh Background
                LiquidMeshBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Connection Status Glass Header
                        HStack(spacing: 10) {
                            Circle()
                                .fill(api.isConnected ? Color.green : Color.orange)
                                .frame(width: 10, height: 10)
                                .shadow(color: (api.isConnected ? Color.green : Color.orange).opacity(0.6), radius: 6)

                            Text(api.isConnected ? "Connected to Host PC Studio" : "Standalone / Disconnected")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            Spacer()

                            LiquidGlassPill(
                                text: api.runMode == .onDevice ? "Standalone" : "Remote",
                                icon: api.runMode == .onDevice ? "bolt.shield.fill" : "network",
                                tintColor: api.runMode == .onDevice ? .cyan : .purple
                            )
                        }
                        .padding(14)
                        .liquidGlassCard(cornerRadius: 18)

                        // Manual Host Input Card
                        VStack(alignment: .leading, spacing: 10) {
                            Text("HOST PC STUDIO ADDRESS")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.cyan)
                                .tracking(0.5)

                            HStack {
                                TextField("http://192.168.x.x:8000", text: $inputHost)
                                    .keyboardType(.URL)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .font(.system(size: 13))
                                    .padding(12)
                                    .background(Color.black.opacity(0.35))
                                    .cornerRadius(12)
                                    .foregroundColor(.white)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))

                                Button(action: testConnection) {
                                    HStack {
                                        if isTesting {
                                            ProgressView().tint(.black)
                                        } else {
                                            Text("Connect")
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        LinearGradient(colors: [Color.cyan, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .foregroundColor(.black)
                                    .cornerRadius(12)
                                }
                            }

                            Text("Connect your iPhone and PC to the same Wi-Fi network to enable two-way sync.")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(16)
                        .liquidGlassCard(cornerRadius: 22)

                        // Quick Presets
                        VStack(alignment: .leading, spacing: 10) {
                            Text("DETECTED LOCAL PRESETS")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.cyan)
                                .tracking(0.5)

                            Button(action: {
                                inputHost = "http://192.168.11.146:8000"
                                testConnection()
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "wifi")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.cyan)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Local Wi-Fi PC Studio")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                        Text("192.168.11.146:8000")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding(12)
                                .liquidGlassCard(cornerRadius: 14)
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                inputHost = "http://localhost:8000"
                                testConnection()
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "laptopcomputer")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.purple)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Simulator / Localhost")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                        Text("localhost:8000")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding(12)
                                .liquidGlassCard(cornerRadius: 14)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(16)
                        .liquidGlassCard(cornerRadius: 22)

                        if let res = testResult {
                            HStack {
                                Image(systemName: res.contains("Success") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundColor(res.contains("Success") ? .green : .orange)
                                Text(res)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .padding(12)
                            .liquidGlassCard(cornerRadius: 14)
                        }

                        // Extra bottom spacing for floating tab bar
                        Spacer(minLength: 90)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                }
            }
            .navigationTitle("PC Studio Connect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.cyan)
                }
            }
            .onAppear {
                inputHost = api.baseURL
            }
        }
    }

    private func testConnection() {
        guard !inputHost.isEmpty else { return }
        api.baseURL = inputHost
        isTesting = true
        testResult = nil
        Task {
            let ok = await api.pingServer()
            isTesting = false
            if ok {
                testResult = "Successfully connected to StoryTeller PC Studio!"
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } else {
                testResult = "Could not reach PC server. Please ensure both devices are on the same Wi-Fi and the python studio is running."
            }
        }
    }
}
