import Foundation
import Photos
import UIKit

@MainActor
public class StoryTellerAPIService: ObservableObject {
    public static let shared = StoryTellerAPIService()

    // Run Mode: Default is Standalone (works 100% on iPhone without PC)
    @Published public var runMode: AppRunMode {
        didSet {
            UserDefaults.standard.set(runMode.rawValue, forKey: "storyteller_run_mode")
        }
    }

    @Published public var baseURL: String {
        didSet {
            UserDefaults.standard.set(baseURL, forKey: "storyteller_base_url")
        }
    }

    @Published public var isConnected: Bool = false
    @Published public var presets: PresetsResponse?
    @Published public var isGenerating: Bool = false
    @Published public var generationProgressText: String = ""
    @Published public var generationPercent: Double = 0.0

    // Custom background picked from iPhone Photos
    @Published public var customBackgroundURL: URL?

    public init() {
        let savedMode = UserDefaults.standard.string(forKey: "storyteller_run_mode")
        self.runMode = (savedMode == AppRunMode.remotePC.rawValue) ? .remotePC : .onDevice

        let savedURL = UserDefaults.standard.string(forKey: "storyteller_base_url")
        self.baseURL = savedURL ?? "http://192.168.11.146:8000"

        loadLocalPresets()
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

    public func loadLocalPresets() {
        let voices = NativeSpeechService.shared.getAvailableVoices()
        let bgs = NativeBackgroundService.shared.availablePresets.map {
            PresetOption(id: $0.id, name: $0.name, description: $0.category)
        }
        let subreddits = [
            PresetOption(id: "AmItheAsshole", name: "r/AmItheAsshole (Viral Drama)"),
            PresetOption(id: "MaliciousCompliance", name: "r/MaliciousCompliance (Petty Revenge)"),
            PresetOption(id: "nosleep", name: "r/nosleep (Scary Encounters)"),
            PresetOption(id: "confession", name: "r/confession (Deep Secrets)"),
            PresetOption(id: "LifeProTips", name: "r/LifeProTips (Psychology Hacks)"),
            PresetOption(id: "Showerthoughts", name: "r/Showerthoughts (Mindbending)")
        ]
        let styles = [
            PresetOption(id: "auto", name: "✨ AI Auto-Style (Pacing-Optimized)"),
            PresetOption(id: "karaoke", name: "CapCut Karaoke (Word-by-word highlight)"),
            PresetOption(id: "single", name: "MrBeast Bouncing Word (High velocity)")
        ]
        let colors = [
            PresetOption(id: "auto", name: "✨ AI Auto-Color (High Contrast)"),
            PresetOption(id: "&H00FFFF&", name: "TikTok Yellow (Default)"),
            PresetOption(id: "&H00FF00&", name: "Neon Lime Green"),
            PresetOption(id: "&HFFFF00&", name: "Electric Cyan"),
            PresetOption(id: "&H0000FF&", name: "Hot Coral Red")
        ]
        self.presets = PresetsResponse(
            voices: voices,
            subreddits: subreddits,
            backgrounds: bgs,
            subtitle_styles: styles,
            highlight_colors: colors
        )
    }

    // MARK: - Server Ping Check (Remote PC Mode)
    public func pingServer() async -> Bool {
        guard let url = URL(string: "\(cleanBaseURL)/api/presets") else { return false }
        do {
            var req = URLRequest(url: url)
            req.timeoutInterval = 3
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                let decoder = JSONDecoder()
                if let p = try? decoder.decode(PresetsResponse.self, from: data) {
                    self.presets = p
                }
                self.isConnected = true
                return true
            }
        } catch {
            self.isConnected = false
        }
        self.isConnected = false
        return false
    }

    // MARK: - AI Story Analysis
    public func analyzeStory(story: String, title: String = "") async throws -> AIMatch {
        if runMode == .onDevice || !isConnected {
            return NativeScraperService.shared.analyzeStoryVibe(story: story, title: title)
        }

        guard let url = URL(string: "\(cleanBaseURL)/api/ai/analyze-story") else {
            return NativeScraperService.shared.analyzeStoryVibe(story: story, title: title)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 6
        let body: [String: String] = ["story": story, "title": title]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            struct Resp: Codable {
                let status: String
                let analysis: AIMatch
            }
            let res = try JSONDecoder().decode(Resp.self, from: data)
            return res.analysis
        } catch {
            return NativeScraperService.shared.analyzeStoryVibe(story: story, title: title)
        }
    }

    // MARK: - Reddit Scraping
    public func fetchRedditStories(subreddit: String = "AmItheAsshole") async throws -> [Story] {
        if runMode == .onDevice || !isConnected {
            return try await NativeScraperService.shared.fetchRedditStories(subreddit: subreddit)
        }

        let endpoint = "\(cleanBaseURL)/api/reddit/stories?subreddit=\(subreddit.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subreddit)"
        guard let url = URL(string: endpoint) else {
            return try await NativeScraperService.shared.fetchRedditStories(subreddit: subreddit)
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            struct Resp: Codable {
                let stories: [Story]
            }
            let res = try JSONDecoder().decode(Resp.self, from: data)
            return res.stories
        } catch {
            return try await NativeScraperService.shared.fetchRedditStories(subreddit: subreddit)
        }
    }

    public func scrapeRedditURL(url: String) async throws -> Story {
        if runMode == .onDevice || !isConnected {
            return try await NativeScraperService.shared.fetchRedditURL(url)
        }

        guard let endpoint = URL(string: "\(cleanBaseURL)/api/reddit/url") else {
            return try await NativeScraperService.shared.fetchRedditURL(url)
        }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["url": url])
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            struct Resp: Codable {
                let post: Story
            }
            let res = try JSONDecoder().decode(Resp.self, from: data)
            return res.post
        } catch {
            return try await NativeScraperService.shared.fetchRedditURL(url)
        }
    }

    // MARK: - Quora
    public func fetchQuoraStories(query: String = "viral secrets") async throws -> [Story] {
        if runMode == .onDevice || !isConnected {
            // Instant offline secret/confession stories
            return [
                NativeScraperService.shared.generateOfflineAIStory(category: "confessions", prompt: query),
                NativeScraperService.shared.generateOfflineAIStory(category: "lifehacks", prompt: query),
                NativeScraperService.shared.generateOfflineAIStory(category: "truecrime", prompt: query)
            ]
        }

        let endpoint = "\(cleanBaseURL)/api/quora/stories?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
        guard let url = URL(string: endpoint) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        struct Resp: Codable {
            let stories: [Story]
        }
        let res = try JSONDecoder().decode(Resp.self, from: data)
        return res.stories
    }

    // MARK: - YouTube
    public func fetchYouTubeTranscript(url: String) async throws -> Story {
        if runMode == .onDevice || !isConnected {
            return try await NativeScraperService.shared.fetchYouTubePodcastStory(url: url)
        }

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

    // MARK: - AI Writer
    public func generateAIStory(category: String, prompt: String = "", duration: Int = 60) async throws -> Story {
        if runMode == .onDevice || !isConnected {
            return NativeScraperService.shared.generateOfflineAIStory(category: category, prompt: prompt, duration: duration)
        }

        guard let endpoint = URL(string: "\(cleanBaseURL)/api/ai/generate") else {
            return NativeScraperService.shared.generateOfflineAIStory(category: category, prompt: prompt, duration: duration)
        }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "category": category,
            "prompt": prompt,
            "duration": duration
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            struct Resp: Codable {
                let result: Story
            }
            let res = try JSONDecoder().decode(Resp.self, from: data)
            return res.result
        } catch {
            return NativeScraperService.shared.generateOfflineAIStory(category: category, prompt: prompt, duration: duration)
        }
    }

    // MARK: - Video Generator (Unified: 100% On-Device Standalone or Remote PC)
    public func generateVideo(
        title: String,
        story: String,
        voice: String = "auto",
        rate: String = "auto",
        background: String = "auto",
        subtitleStyle: String = "auto",
        highlightColor: String = "auto"
    ) async throws -> GenerationResult {
        isGenerating = true
        generationPercent = 0.05
        generationProgressText = "Analyzing story vibe & matching persona..."
        defer {
            isGenerating = false
            generationPercent = 0.0
        }

        // 1. Analyze vibe
        let analysis = try await analyzeStory(story: story, title: title)
        let resolvedVoice = (voice == "auto") ? analysis.recommended_voice : voice
        let resolvedBg = (background == "auto") ? analysis.recommended_bg : background
        let resolvedColor = (highlightColor == "auto") ? analysis.recommended_color : highlightColor
        let resolvedStyle = (subtitleStyle == "auto") ? analysis.subtitle_style : subtitleStyle

        if runMode == .onDevice || !isConnected {
            // ==========================================
            // 📱 100% ON-DEVICE IPHONE PIPELINE
            // ==========================================
            generationProgressText = "Synthesizing voiceover on iPhone..."
            generationPercent = 0.15

            var rateMultiplier: Float = 1.05
            if rate == "+12%" || analysis.recommended_rate == "+12%" { rateMultiplier = 1.12 }
            if rate == "+18%" || analysis.recommended_rate == "+18%" { rateMultiplier = 1.18 }

            // Step A: Native Speech
            let speech = try await NativeSpeechService.shared.synthesizeStory(
                text: "\(title). \(story)",
                voiceId: resolvedVoice,
                rateMultiplier: rateMultiplier
            )

            // Step B: Resolve Background B-Roll
            generationProgressText = "Preparing 9:16 vertical background footage..."
            generationPercent = 0.35

            let bgURL = try await NativeBackgroundService.shared.resolveBackgroundVideo(
                id: resolvedBg,
                customVideoURL: customBackgroundURL
            ) { [weak self] status in
                Task { @MainActor in
                    self?.generationProgressText = status
                }
            }

            // Step C: Native Video Composition
            let compOptions = NativeVideoCompositor.CompositionOptions(
                title: title,
                backgroundVideoURL: bgURL,
                narrationAudioURL: speech.audioURL,
                audioDuration: speech.duration,
                wordTimestamps: speech.words,
                subtitleStyle: resolvedStyle,
                highlightColorHex: resolvedColor
            ) { [weak self] pct, status in
                Task { @MainActor in
                    self?.generationPercent = pct
                    self?.generationProgressText = status
                }
            }

            let renderedVideoURL = try await NativeVideoCompositor.shared.composeVideo(options: compOptions)

            let wordCount = story.split(whereSeparator: \.isWhitespace).count
            let safeTitle = title.replacingOccurrences(of: "\"", with: "")
            let caption = "\(safeTitle) 🤯 Wait for the end... What would you do? 👇"
            let hashtags = "#fyp #redditstories #storytime #aita #viral #tiktok #trending"

            return GenerationResult(
                job_id: UUID().uuidString,
                title: title,
                duration: round(speech.duration * 10) / 10.0,
                video_filename: renderedVideoURL.lastPathComponent,
                thumbnail_filename: nil,
                caption: caption,
                hashtags: hashtags,
                word_count: wordCount,
                ai_match: analysis,
                localFileURL: renderedVideoURL.absoluteString
            )
        } else {
            // ==========================================
            // 💻 REMOTE PC PIPELINE
            // ==========================================
            guard let endpoint = URL(string: "\(cleanBaseURL)/api/video/generate") else { throw URLError(.badURL) }
            var req = URLRequest(url: endpoint)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.timeoutInterval = 120

            let body: [String: String] = [
                "title": title,
                "story": story,
                "voice": resolvedVoice,
                "rate": rate,
                "background_id": resolvedBg,
                "subtitle_style": resolvedStyle,
                "highlight_color": resolvedColor
            ]
            req.httpBody = try JSONSerialization.data(withJSONObject: body)

            generationProgressText = "PC server rendering video..."
            generationPercent = 0.50

            let (data, _) = try await URLSession.shared.data(for: req)
            struct Resp: Codable {
                let status: String
                let data: GenerationResult
            }
            let res = try JSONDecoder().decode(Resp.self, from: data)
            return res.data
        }
    }

    // MARK: - Gallery
    public func fetchGallery() async throws -> [GalleryVideo] {
        if runMode == .onDevice || !isConnected {
            // Read generated videos from iPhone documents directory
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            guard let files = try? FileManager.default.contentsOfDirectory(at: docs, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey], options: .skipsHiddenFiles) else {
                return []
            }

            var videos: [GalleryVideo] = []
            for file in files where file.pathExtension.lowercased() == "mp4" {
                let attrs = try? FileManager.default.attributesOfItem(atPath: file.path)
                let sizeBytes = attrs?[.size] as? Int64 ?? 0
                let modDate = attrs?[.modificationDate] as? Date ?? Date()
                let sizeMB = Double(sizeBytes) / (1024.0 * 1024.0)

                videos.append(GalleryVideo(
                    filename: file.lastPathComponent,
                    url: file.absoluteString,
                    thumbnail_url: nil,
                    size_mb: round(sizeMB * 10) / 10.0,
                    created_at: modDate.timeIntervalSince1970
                ))
            }
            return videos.sorted { $0.created_at > $1.created_at }
        }

        guard let endpoint = URL(string: "\(cleanBaseURL)/api/gallery") else { return [] }
        let (data, _) = try await URLSession.shared.data(from: endpoint)
        struct Resp: Codable {
            let videos: [GalleryVideo]
        }
        let res = try JSONDecoder().decode(Resp.self, from: data)
        return res.videos
    }

    // MARK: - Save to iPhone Camera Roll
    public func saveVideoToCameraRoll(videoRelativeURL: String) async throws {
        var videoURL: URL?
        if videoRelativeURL.starts(with: "file://") {
            videoURL = URL(string: videoRelativeURL)
        } else if videoRelativeURL.starts(with: "http") {
            videoURL = URL(string: videoRelativeURL)
        } else {
            videoURL = URL(string: "\(cleanBaseURL)\(videoRelativeURL)")
        }

        guard let targetURL = videoURL else {
            throw URLError(.badURL)
        }

        var localFileToSave: URL = targetURL
        if targetURL.scheme == "http" || targetURL.scheme == "https" {
            let (temp, _) = try await URLSession.shared.download(from: targetURL)
            let dest = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mp4")
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.copyItem(at: temp, to: dest)
            localFileToSave = dest
        }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw NSError(domain: "StoryTeller", code: 403, userInfo: [NSLocalizedDescriptionKey: "Photos access was denied. Please allow access in Settings to save videos."])
        }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: localFileToSave)
        }
    }
}
