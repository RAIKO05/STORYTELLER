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
                Color(red: 0.05, green: 0.06, blue: 0.09).ignoresSafeArea()

                VStack(spacing: 24) {
                    // Status Badge
                    HStack {
                        Circle()
                            .fill(api.isConnected ? Color.green : Color.orange)
                            .frame(width: 10, height: 10)
                        Text(api.isConnected ? "Connected to Host PC" : "Disconnected")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("HOST PC ADDRESS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)

                        HStack {
                            TextField("http://192.168.x.x:8000", text: $inputHost)
                                .keyboardType(.URL)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .padding(12)
                                .background(Color(red: 0.09, green: 0.12, blue: 0.18))
                                .cornerRadius(10)
                                .foregroundColor(.white)

                            Button(action: testConnection) {
                                if isTesting {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Test")
                                        .font(.system(size: 13, weight: .bold))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(LinearGradient(colors: [Color.cyan, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .foregroundColor(.black)
                                        .cornerRadius(10)
                                }
                            }
                        }

                        Text("Make sure your iPhone is connected to the same Wi-Fi network as your PC.")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)

                    // Quick Preset Buttons
                    VStack(alignment: .leading, spacing: 10) {
                        Text("SAVED / DETECTED ADDRESSES")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)

                        Button(action: {
                            inputHost = "http://192.168.11.146:8000"
                            testConnection()
                        }) {
                            HStack {
                                Image(systemName: "wifi")
                                    .foregroundColor(.cyan)
                                Text("Local Wi-Fi PC (192.168.11.146:8000)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(12)
                            .background(Color(red: 0.09, green: 0.12, blue: 0.18))
                            .cornerRadius(8)
                        }

                        Button(action: {
                            inputHost = "http://localhost:8000"
                            testConnection()
                        }) {
                            HStack {
                                Image(systemName: "laptopcomputer")
                                    .foregroundColor(.purple)
                                Text("Simulator / Localhost (localhost:8000)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(12)
                            .background(Color(red: 0.09, green: 0.12, blue: 0.18))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)

                    if let result = testResult {
                        Text(result)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(api.isConnected ? .green : .red)
                            .padding(.horizontal)
                    }

                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle("Connect to PC")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        api.baseURL = inputHost
                        dismiss()
                    }
                    .foregroundColor(.cyan)
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                inputHost = api.baseURL
            }
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil
        api.baseURL = inputHost
        Task {
            let ok = await api.pingServer()
            isTesting = false
            testResult = ok ? "✅ Connection Successful!" : "❌ Cannot reach PC. Check IP and Wi-Fi."
        }
    }
}
