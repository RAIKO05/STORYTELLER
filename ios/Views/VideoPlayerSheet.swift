import SwiftUI
import AVKit

public struct VideoPlayerSheet: View {
    public let result: GenerationResult
    @ObservedObject var api = StoryTellerAPIService.shared
    @ObservedObject private var themeManager = AppThemeManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var player: AVPlayer?
    @State private var isSaving: Bool = false
    @State private var saveMessage: String?
    @State private var isCopied: Bool = false

    public init(result: GenerationResult) {
        self.result = result
    }

    private var fullVideoURL: URL? {
        if let local = result.localFileURL, let localURL = URL(string: local) {
            return localURL
        }
        let path = "/outputs/\(result.video_filename)"
        return URL(string: "\(api.baseURL)\(path)")
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                // Liquid Mesh Canvas
                LiquidMeshBackground()

                VStack(spacing: 14) {
                    // 9:16 Vertical Video Player Container
                    ZStack {
                        if let player = player {
                            VideoPlayer(player: player)
                                .aspectRatio(9/16, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [
                                                    BayanTokens.gold.opacity(0.70),
                                                    BayanTokens.goldSoft.opacity(0.35),
                                                    Color.white.opacity(0.10)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                )
                                .shadow(color: Color.black.opacity(0.5), radius: 24, y: 12)
                                .shadow(color: themeManager.currentTheme.accentColor.opacity(0.2), radius: 30, y: 4)
                        } else {
                            Rectangle()
                                .fill(Color.black.opacity(0.5))
                                .aspectRatio(9/16, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                .overlay(ProgressView().tint(themeManager.currentTheme.accentColor))
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 4)

                    // Floating Liquid Glass Action Controls
                    VStack(spacing: 10) {
                        // 1. Primary Save to Photos Status Button
                        Button(action: saveToCameraRoll) {
                            HStack(spacing: 8) {
                                if isSaving {
                                    ProgressView().tint(themeManager.currentTheme.ctaTextColor)
                                } else {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 16, weight: .bold))
                                    Text(saveMessage ?? (result.localFileURL != nil ? "SAVED IN PHOTOS ✅" : "SAVE TO IPHONE PHOTOS"))
                                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(themeManager.currentTheme.ctaGradient)
                            .foregroundColor(themeManager.currentTheme.ctaTextColor)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: themeManager.currentTheme.accentColor.opacity(0.35), radius: 10, y: 4)
                        }
                        .disabled(isSaving)
                        .buttonStyle(LiquidGlassButtonStyle())

                        // 2. Share to TikTok / Reels / Shorts Button
                        if let url = fullVideoURL {
                            ShareLink(item: url, message: Text("\(result.caption) \(result.hashtags)")) {
                                HStack(spacing: 8) {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 14, weight: .bold))
                                    Text("Post to TikTok / Reels / Shorts")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .foregroundColor(themeManager.currentTheme.textPrimary)
                                .background(
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(.ultraThinMaterial)
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(themeManager.currentTheme.cardBackground)
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(themeManager.currentTheme.cardStroke, lineWidth: 1)
                                    }
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(LiquidGlassButtonStyle())
                        }

                        // 3. Copy Caption & Viral Hashtags
                        Button(action: copyCaption) {
                            HStack(spacing: 6) {
                                Image(systemName: isCopied ? "checkmark" : "doc.on.doc.fill")
                                    .font(.system(size: 12))
                                Text(isCopied ? "Copied to Clipboard!" : "Copy Caption & Viral Tags")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(themeManager.currentTheme.accentColor)
                            .padding(.vertical, 6)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 12)
                }
            }
            .navigationTitle("Viral Video Ready")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        player?.pause()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(themeManager.currentTheme.textPrimary.opacity(0.75))
                    }
                }
            }
            .onAppear {
                setupPlayer()
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
        }
    }

    private func setupPlayer() {
        guard let url = fullVideoURL else { return }
        let playerItem = AVPlayerItem(url: url)
        self.player = AVPlayer(playerItem: playerItem)
        self.player?.play()

        // Loop playback automatically
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }
    }

    private func saveToCameraRoll() {
        guard let url = fullVideoURL else { return }
        isSaving = true
        Task {
            do {
                try await api.saveVideoToCameraRoll(videoRelativeURL: url.absoluteString)
                saveMessage = "SAVED TO PHOTOS! ✅"
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                #endif
            } catch {
                saveMessage = "Error: \(error.localizedDescription)"
            }
            isSaving = false
        }
    }

    private func copyCaption() {
        let full = "\(result.caption)\n\n\(result.hashtags)"
        UIPasteboard.general.string = full
        isCopied = true
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isCopied = false
        }
    }
}
