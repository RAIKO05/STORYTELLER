import Foundation
import Photos
import UIKit

@MainActor
public class StoryTellerAPIService: ObservableObject {
    public static let shared = StoryTellerAPIService()

    @Published public var baseURL: String {
        didSet {
            UserDefaults.standard.set(baseURL, forKey: "storyteller_base_url")
        }
    }

    @Published public var isConnected: Bool = false
    @Published public var presets: PresetsResponse?
    @Published public var isGenerating: Bool = false
    @Published public var generationProgressText: String = ""

    public init() {
        let saved = UserDefaults.standard.string(forKey: "storyteller_base_url")
        self.baseURL = saved ?? "http://192.168.11.146:8000"
    }

    private var cleanBaseURL: String {
        var url = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if url.hasSuffix("/") {
            url.removeLast()
        }
        if !url.starts(with: "http://") && !url.starts(with: "https://") {
            url = "http://" + url
        }
        return url
    }

    // Ping check
    public func pingServer() async -> Bool {
        guard let url = URL(string: "\(cleanBaseURL)/api/presets") else { return false }
        do {
            var req = URLRequest(url: url)
            req.timeoutInterval = 4
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                let decoder = JSONDecoder()
                self.presets = try? decoder.decode(PresetsResponse.self, from: data)
                self.isConnected = true
                return true
            }
        } catch {
            self.isConnected = false
        }
        self.isConnected = false
        return false
    }

    // AI Story Analysis
    public func analyzeStory(story: String, title: String = "") async throws -> AIMatch {
        guard let url = URL(string: "\(cleanBaseURL)/api/ai/analyze-story") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["story": story, "title": title]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: req)
        struct Resp: Codable {
            let status: String
            let analysis: AIMatch
        }
        let res = try JSONDecoder().decode(Resp.self, from: data)
        return res.analysis
    }

    // Reddit
    public func fetchRedditStories(subreddit: String = "AmItheAsshole") async throws -> [Story] {
        let endpoint = "\(cleanBaseURL)/api/reddit/stories?subreddit=\(subreddit.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subreddit)"
        guard let url = URL(string: endpoint) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        struct Resp: Codable {
            let stories: [Story]
        }
        let res = try JSONDecoder().decode(Resp.self, from: data)
        return res.stories
    }

    public func scrapeRedditURL(url: String) async throws -> Story {
        guard let endpoint = URL(string: "\(cleanBaseURL)/api/reddit/url") else { throw URLError(.badURL) }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["url": url])
        let (data, _) = try await URLSession.shared.data(for: req)
        struct Resp: Codable {
            let post: Story
        }
        let res = try JSONDecoder().decode(Resp.self, from: data)
        return res.post
    }

    // Quora
    public func fetchQuoraStories(query: String = "viral secrets") async throws -> [Story] {
        let endpoint = "\(cleanBaseURL)/api/quora/stories?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
        guard let url = URL(string: endpoint) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        struct Resp: Codable {
            let stories: [Story]
        }
        let res = try JSONDecoder().decode(Resp.self, from: data)
        return res.stories
    }

    // YouTube
    public func fetchYouTubeTranscript(url: String) async throws -> Story {
        guard let endpoint = URL(string: "\(cleanBaseURL)/api/youtube/transcript") else { throw URLError(.badURL) }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["url": url])
        let (data, _) = try await URLSession.shared.data(for: req)
        struct Resp: Codable {
            let video: Story
        }
        let res = try JSONDecoder().decode(Resp.self, from: data)
        return res.video
    }

    // AI Writer
    public func generateAIStory(category: String, prompt: String = "", duration: Int = 60) async throws -> Story {
        guard let endpoint = URL(string: "\(cleanBaseURL)/api/ai/generate") else { throw URLError(.badURL) }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "category": category,
            "prompt": prompt,
            "duration": duration
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: req)
        struct Resp: Codable {
            let result: Story
        }
        let res = try JSONDecoder().decode(Resp.self, from: data)
        return res.result
    }

    // Video Generator
    public func generateVideo(
        title: String,
        story: String,
        voice: String = "auto",
        rate: String = "auto",
        background: String = "auto",
        subtitleStyle: String = "auto",
        highlightColor: String = "auto"
    ) async throws -> GenerationResult {
        guard let endpoint = URL(string: "\(cleanBaseURL)/api/video/generate") else { throw URLError(.badURL) }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 120 // Video generation can take up to ~30-60s

        let body: [String: String] = [
            "title": title,
            "story": story,
            "voice": voice,
            "rate": rate,
            "background_id": background,
            "subtitle_style": subtitleStyle,
            "highlight_color": highlightColor
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        isGenerating = true
        generationProgressText = "AI matching voice and scrubbing b-roll..."
        defer { isGenerating = false }

        let (data, _) = try await URLSession.shared.data(for: req)
        struct Resp: Codable {
            let status: String
            let data: GenerationResult
        }
        let res = try JSONDecoder().decode(Resp.self, from: data)
        return res.data
    }

    // Gallery
    public func fetchGallery() async throws -> [GalleryVideo] {
        guard let endpoint = URL(string: "\(cleanBaseURL)/api/gallery") else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: endpoint)
        struct Resp: Codable {
            let videos: [GalleryVideo]
        }
        let res = try JSONDecoder().decode(Resp.self, from: data)
        return res.videos
    }

    // Save to iPhone Camera Roll
    public func saveVideoToCameraRoll(videoRelativeURL: String) async throws {
        let fullURLString = videoRelativeURL.starts(with: "http") ? videoRelativeURL : "\(cleanBaseURL)\(videoRelativeURL)"
        guard let videoURL = URL(string: fullURLString) else {
            throw URLError(.badURL)
        }

        // 1. Download to temporary local file
        let (localURL, _) = try await URLSession.shared.download(from: videoURL)
        let tempDir = FileManager.default.temporaryDirectory
        let destinationURL = tempDir.appendingPathComponent("\(UUID().uuidString).mp4")
        try? FileManager.default.removeItem(at: destinationURL)
        try FileManager.default.copyItem(at: localURL, to: destinationURL)

        // 2. Request Photos Library permission
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw NSError(domain: "StoryTeller", code: 403, userInfo: [NSLocalizedDescriptionKey: "Photos access was denied. Please allow access in Settings to save videos."])
        }

        // 3. Save to Photos
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: destinationURL)
        }
    }
}
