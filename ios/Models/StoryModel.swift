import Foundation
import SwiftUI

public struct Story: Identifiable, Codable, Hashable {
    public var id: String
    public var title: String
    public var story: String
    public var author: String?
    public var upvotes: Int?
    public var subreddit: String?
    public var topic: String?

    public init(id: String = UUID().uuidString, title: String, story: String, author: String? = nil, upvotes: Int? = nil, subreddit: String? = nil, topic: String? = nil) {
        self.id = id
        self.title = title
        self.story = story
        self.author = author
        self.upvotes = upvotes
        self.subreddit = subreddit
        self.topic = topic
    }
}

public struct AIMatch: Codable, Hashable {
    public var vibe: String
    public var vibe_key: String
    public var recommended_voice: String
    public var voice_name: String
    public var recommended_rate: String
    public var recommended_color: String
    public var color_name: String
    public var recommended_bg: String
    public var bg_name: String
    public var subtitle_style: String
    public var rationale: String

    public init(
        vibe: String,
        vibe_key: String,
        recommended_voice: String,
        voice_name: String,
        recommended_rate: String,
        recommended_color: String,
        color_name: String,
        recommended_bg: String,
        bg_name: String,
        subtitle_style: String,
        rationale: String
    ) {
        self.vibe = vibe
        self.vibe_key = vibe_key
        self.recommended_voice = recommended_voice
        self.voice_name = voice_name
        self.recommended_rate = recommended_rate
        self.recommended_color = recommended_color
        self.color_name = color_name
        self.recommended_bg = recommended_bg
        self.bg_name = bg_name
        self.subtitle_style = subtitle_style
        self.rationale = rationale
    }
}

public struct WordTiming: Codable, Hashable {
    public var word: String
    public var start: Double
    public var end: Double

    public init(word: String, start: Double, end: Double) {
        self.word = word
        self.start = start
        self.end = end
    }
}

public struct BackgroundOption: Identifiable, Codable, Hashable {
    public var id: String
    public var name: String
    public var category: String
    public var directURL: String?
    public var localFileName: String?
    public var isProcedural: Bool

    public init(id: String, name: String, category: String, directURL: String? = nil, localFileName: String? = nil, isProcedural: Bool = false) {
        self.id = id
        self.name = name
        self.category = category
        self.directURL = directURL
        self.localFileName = localFileName
        self.isProcedural = isProcedural
    }
}

public enum AppRunMode: String, CaseIterable, Identifiable {
    case onDevice = "📱 iPhone Standalone (No PC Needed)"
    case remotePC = "💻 Remote PC Server (Wi-Fi)"

    public var id: String { rawValue }
    public var shortName: String {
        switch self {
        case .onDevice: return "Standalone"
        case .remotePC: return "PC Server"
        }
    }
}

public struct PresetOption: Identifiable, Codable, Hashable {
    public var id: String
    public var name: String
    public var description: String?

    public init(id: String, name: String, description: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
    }
}

public struct PresetsResponse: Codable {
    public var voices: [PresetOption]
    public var subreddits: [PresetOption]
    public var backgrounds: [PresetOption]
    public var subtitle_styles: [PresetOption]
    public var highlight_colors: [PresetOption]

    public init(voices: [PresetOption], subreddits: [PresetOption], backgrounds: [PresetOption], subtitle_styles: [PresetOption], highlight_colors: [PresetOption]) {
        self.voices = voices
        self.subreddits = subreddits
        self.backgrounds = backgrounds
        self.subtitle_styles = subtitle_styles
        self.highlight_colors = highlight_colors
    }
}

public struct GenerationResult: Codable {
    public var job_id: String
    public var title: String
    public var duration: Double
    public var video_filename: String
    public var thumbnail_filename: String?
    public var caption: String
    public var hashtags: String
    public var word_count: Int
    public var ai_match: AIMatch?
    public var localFileURL: String?

    public init(job_id: String, title: String, duration: Double, video_filename: String, thumbnail_filename: String? = nil, caption: String, hashtags: String, word_count: Int, ai_match: AIMatch? = nil, localFileURL: String? = nil) {
        self.job_id = job_id
        self.title = title
        self.duration = duration
        self.video_filename = video_filename
        self.thumbnail_filename = thumbnail_filename
        self.caption = caption
        self.hashtags = hashtags
        self.word_count = word_count
        self.ai_match = ai_match
        self.localFileURL = localFileURL
    }
}

public struct GalleryVideo: Identifiable, Codable, Hashable {
    public var id: String { filename }
    public var filename: String
    public var url: String
    public var thumbnail_url: String?
    public var size_mb: Double
    public var created_at: Double

    public init(filename: String, url: String, thumbnail_url: String? = nil, size_mb: Double, created_at: Double) {
        self.filename = filename
        self.url = url
        self.thumbnail_url = thumbnail_url
        self.size_mb = size_mb
        self.created_at = created_at
    }
}
