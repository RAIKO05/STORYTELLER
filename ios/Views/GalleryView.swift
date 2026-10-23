import SwiftUI

public struct GalleryView: View {
    @ObservedObject var api = StoryTellerAPIService.shared
    @ObservedObject private var themeManager = AppThemeManager.shared
    @State private var videos: [GalleryVideo] = []
    @State private var isLoading: Bool = false
    @State private var selectedVideo: GenerationResult?

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                // Theme Ambient Background
                LiquidMeshBackground()

                if isLoading {
                    ProgressView()
                        .tint(themeManager.currentTheme.accentColor)
                } else if videos.isEmpty {
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(themeManager.currentTheme.accentColor.opacity(0.12))
                                .frame(width: 80, height: 80)
                                .blur(radius: 6)
                            Image(systemName: "film.stack")
                                .font(.system(size: 38))
                                .foregroundColor(themeManager.currentTheme.accentColor)
                        }

                        Text("No Videos Generated Yet")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(themeManager.currentTheme.textPrimary)

                        Text("Create your first viral video right on your iPhone!")
                            .font(.system(size: 13))
                            .foregroundColor(themeManager.currentTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(32)
                    .liquidGlassCard(cornerRadius: 24, isGoldBorder: true)
                    .padding(.horizontal, 24)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 14) {
                            ForEach(videos) { vid in
                                Button(action: {
                                    self.selectedVideo = GenerationResult(
                                        job_id: vid.filename,
                                        title: vid.filename.replacingOccurrences(of: ".mp4", with: "").replacingOccurrences(of: "StoryTeller_", with: ""),
                                        duration: 45.0,
                                        video_filename: vid.filename,
                                        thumbnail_filename: vid.thumbnail_url,
                                        caption: "Viral TikTok Story 🤯 #fyp #viral #storytime",
                                        hashtags: "#fyp #viral #tiktok #trending #redditstories",
                                        word_count: 100,
                                        ai_match: nil,
                                        localFileURL: vid.url.starts(with: "file://") ? vid.url : nil
                                    )
                                    #if os(iOS)
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    #endif
                                }) {
                                    HStack(spacing: 14) {
                                        // Video Thumbnail Glass Container
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(themeManager.currentTheme.cardBackground)
                                                .frame(width: 64, height: 86)

                                            Image(systemName: "play.circle.fill")
                                                .font(.system(size: 28))
                                                .foregroundStyle(themeManager.currentTheme.ctaGradient)
                                                .shadow(color: themeManager.currentTheme.accentColor.opacity(0.4), radius: 6)
                                        }

                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(vid.filename.replacingOccurrences(of: ".mp4", with: ""))
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                                .foregroundColor(themeManager.currentTheme.textPrimary)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)

                                            HStack(spacing: 8) {
                                                Text("\(String(format: "%.1f", vid.size_mb)) MB")
                                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                                    .foregroundColor(themeManager.currentTheme.textSecondary)

                                                if vid.url.starts(with: "file://") {
                                                    LiquidGlassPill(text: "On-Device", icon: "iphone", isGold: true)
                                                }
                                            }
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(themeManager.currentTheme.textSecondary.opacity(0.6))
                                    }
                                    .padding(12)
                                    .liquidGlassCard(cornerRadius: 18)
                                }
                                .buttonStyle(.plain)
                            }

                            // Extra bottom padding for floating capsule dock
                            Spacer(minLength: 100)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }
                }
            }
            .navigationTitle("Video Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: refreshGallery) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(themeManager.currentTheme.accentColor)
                    }
                }
            }
            .sheet(item: $selectedVideo) { res in
                VideoPlayerSheet(result: res)
            }
            .onAppear(perform: refreshGallery)
        }
    }

    private func refreshGallery() {
        isLoading = true
        Task {
            do {
                let list = try await api.fetchGallery()
                self.videos = list
            } catch {
                print("Failed to fetch gallery: \(error)")
            }
            isLoading = false
        }
    }
}
