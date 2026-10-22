import Foundation

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
}

public struct PresetOption: Identifiable, Codable, Hashable {
    public var id: String
    public var name: String
    public var description: String?
}

public struct PresetsResponse: Codable {
    public var voices: [PresetOption]
    public var subreddits: [PresetOption]
    public var backgrounds: [PresetOption]
    public var subtitle_styles: [PresetOption]
    public var highlight_colors: [PresetOption]
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
}

public struct GalleryVideo: Identifiable, Codable, Hashable {
    public var id: String { filename }
    public var filename: String
    public var url: String
    public var thumbnail_url: String?
    public var size_mb: Double
    public var created_at: Double
}
