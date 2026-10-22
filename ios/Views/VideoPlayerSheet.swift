import SwiftUI
import AVKit

public struct VideoPlayerSheet: View {
    public let result: GenerationResult
    @ObservedObject var api = StoryTellerAPIService.shared
    @Environment(\.dismiss) var dismiss

    @State private var player: AVPlayer?
    @State private var isSaving: Bool = false
    @State private var saveMessage: String?
    @State private var isCopied: Bool = false

    public init(result: GenerationResult) {
        self.result = result
    }

    private var fullVideoURL: URL? {
        let path = "/outputs/\(result.video_filename)"
        return URL(string: "\(api.baseURL)\(path)")
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 16) {
                    // Vertical 9:16 Video View
                    if let player = player {
                        VideoPlayer(player: player)
                            .aspectRatio(9/16, contentMode: .fit)
                            .cornerRadius(18)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color(red: 0.2, green: 0.25, blue: 0.35), lineWidth: 2)
                            )
                            .shadow(color: .cyan.opacity(0.3), radius: 12)
                            .padding(.horizontal, 24)
                    } else {
                        Rectangle()
                            .fill(Color(red: 0.1, green: 0.1, blue: 0.15))
                            .aspectRatio(9/16, contentMode: .fit)
                            .cornerRadius(18)
                            .overlay(ProgressView().tint(.white))
                            .padding(.horizontal, 24)
                    }

                    // Action Buttons Row
                    VStack(spacing: 10) {
                        // 1. Save to Photos Button
                        Button(action: saveToCameraRoll) {
                            HStack {
                                if isSaving {
                                    ProgressView().tint(.black)
                                } else {
                                    Image(systemName: "square.and.arrow.down.fill")
                                    Text(saveMessage ?? "Save to iPhone Photos (Camera Roll)")
                                        .fontWeight(.bold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(LinearGradient(colors: [Color.green, Color(red: 0.2, green: 0.8, blue: 0.4)], startPoint: .leading, endPoint: .trailing))
                            .foregroundColor(.black)
                            .cornerRadius(12)
                        }
                        .disabled(isSaving)

                        // 2. Copy Caption & Hashtags
                        Button(action: copyCaption) {
                            HStack {
                                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                Text(isCopied ? "Copied to Clipboard!" : "Copy Caption & Viral Hashtags")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(red: 0.12, green: 0.16, blue: 0.24))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }

                        // 3. Native Share Link
                        if let url = fullVideoURL {
                            ShareLink(item: url) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Share Video Link / AirDrop")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(.cyan)
                                .padding(.top, 4)
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: 10)
                }
                .padding(.top, 10)
            }
            .navigationTitle(result.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        player?.pause()
                        dismiss()
                    }
                    .foregroundColor(.cyan)
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                if let url = fullVideoURL {
                    let avPlayer = AVPlayer(url: url)
                    self.player = avPlayer
                    avPlayer.play()
                }
            }
            .onDisappear {
                player?.pause()
            }
        }
    }

    private func saveToCameraRoll() {
        isSaving = true
        saveMessage = "Downloading & Saving..."
        Task {
            do {
                try await api.saveVideoToCameraRoll(videoRelativeURL: "/outputs/\(result.video_filename)")
                saveMessage = "✅ Saved to Photos!"
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            } catch {
                saveMessage = "❌ Save failed: \(error.localizedDescription)"
            }
            isSaving = false
        }
    }

    private func copyCaption() {
        UIPasteboard.general.string = result.caption
        isCopied = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isCopied = false
        }
    }
}
