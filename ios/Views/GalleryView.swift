import SwiftUI

public struct GalleryView: View {
    @ObservedObject var api = StoryTellerAPIService.shared
    @State private var videos: [GalleryVideo] = []
    @State private var isLoading: Bool = false
    @State private var selectedVideo: GenerationResult?

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.06, blue: 0.09).ignoresSafeArea()

                if isLoading {
                    ProgressView().tint(.cyan)
                } else if videos.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "film.stack")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No Videos Generated Yet")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        Text(api.runMode == .onDevice ? "Create your first viral video right on your iPhone!" : "Create your first viral video in the Studio tab!")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
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
                                }) {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color(red: 0.12, green: 0.16, blue: 0.24))
                                                .frame(width: 60, height: 80)
                                            Image(systemName: "play.circle.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(.cyan)
                                        }

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(vid.filename.replacingOccurrences(of: ".mp4", with: ""))
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.white)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)

                                            HStack(spacing: 8) {
                                                Text("\(String(format: "%.1f", vid.size_mb)) MB")
                                                    .font(.system(size: 11, design: .monospaced))
                                                    .foregroundColor(.gray)

                                                if vid.url.starts(with: "file://") {
                                                    Text("📱 On-Device")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .padding(.horizontal, 5)
                                                        .padding(.vertical, 2)
                                                        .background(Color.cyan.opacity(0.2))
                                                        .foregroundColor(.cyan)
                                                        .cornerRadius(4)
                                                }
                                            }
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                    }
                                    .padding(10)
                                    .background(Color(red: 0.08, green: 0.10, blue: 0.15))
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.16, green: 0.20, blue: 0.30), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Video Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: refreshGallery) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.cyan)
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
