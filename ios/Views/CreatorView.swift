import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// Transferable helper for PhotosPicker video selection
public struct MovieFile: Transferable {
    public let url: URL

    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent("custom_bg_\(UUID().uuidString).mp4")
            try? FileManager.default.removeItem(at: copy)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self(url: copy)
        }
    }
}

public struct CreatorView: View {
    @ObservedObject var api = StoryTellerAPIService.shared
    @ObservedObject private var themeManager = AppThemeManager.shared

    // Story Source Selection
    enum SourceType: String, CaseIterable, Identifiable {
        case curated = "Curated 🔥"
        case reddit = "Reddit"
        case ai = "AI Writer"
        case quora = "Quora"
        case youtube = "YouTube"
        case custom = "Custom"
        public var id: String { rawValue }

        var icon: String {
            switch self {
            case .curated: return "flame.fill"
            case .reddit: return "bubble.left.and.bubble.right.fill"
            case .ai: return "wand.and.stars"
            case .quora: return "lightbulb.fill"
            case .youtube: return "play.rectangle.fill"
            case .custom: return "pencil.line"
            }
        }
    }

    @State private var selectedSource: SourceType = .curated
    @State private var storyTitle: String = ""
    @State private var storyText: String = ""

    // Source inputs
    @State private var subreddit: String = "AmItheAsshole"
    @State private var redditStories: [Story] = []
    @State private var redditURL: String = ""

    @State private var quoraQuery: String = "viral secrets"
    @State private var quoraStories: [Story] = []
    @State private var quoraURL: String = ""

    @State private var youtubeURL: String = ""

    @State private var aiCategory: String = "aita"
    @State private var aiPrompt: String = ""
    @State private var aiDuration: Int = 60

    // Customization
    @State private var selectedVoice: String = "auto"
    @State private var selectedRate: String = "auto"
    @State private var selectedBackground: String = "auto"
    @State private var selectedColor: String = "auto"

    // PhotosPicker for custom B-roll
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var customBgFilename: String?

    // AI Match State
    @State private var aiMatch: AIMatch?
    @State private var isAnalyzing: Bool = false
    @State private var analyzeTask: Task<Void, Never>?

    // Studio Features State
    @State private var showHookDoctorSheet: Bool = false
    @State private var isPlayingVoicePreview: Bool = false
    @State private var selectedBgMusic: String = "cinematic_ambient"
    @State private var voiceVolume: Double = 1.0 // 0.5 - 1.5
    @State private var bgMusicVolume: Double = 0.15 // 0.0 - 0.40
    @State private var subtitlePosition: String = "lower" // lower, center, upper
    @State private var subtitleFontSize: Double = 52.0 // 52, 64, 76
    @State private var storyParts: StoryParts? = nil
    @State private var activePart: Int = 1

    // Generation & Sheets
    @State private var showConnectSheet: Bool = false
    @State private var showThemeSheet: Bool = false
    @State private var generatedResult: GenerationResult?
    @State private var errorMessage: String?
    @State private var isLoadingSource: Bool = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                // 1. Ambient Dynamic Mesh Canvas
                LiquidMeshBackground()

                // 2. Main Scrollable Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        // Header Status Pill & Title
                        topHeaderSection

                        // App Mode Segmented Capsule
                        modeSwitcherCapsule

                        // Source Tabs (Horizontal Glass Carousel)
                        sourceSelectorBar

                        // Subview based on active source
                        activeSourceControls

                        // Story Editor Glass Card
                        storyEditorCard

                        // AI Match Holographic Glass Banner
                        if let match = aiMatch {
                            aiMatchCard(match)
                        }

                        // Voice, Pacing & B-Roll Glass Card
                        controlsGlassCard

                        // CTA Section
                        generateSection

                        // Extra bottom spacing for floating capsule dock
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 8) {
                        Image("AppLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(BayanTokens.glassGoldStroke, lineWidth: 0.8))
                            .shadow(color: themeManager.currentTheme.accentColor.opacity(0.35), radius: 4)

                        Text("StoryTeller")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundColor(themeManager.currentTheme.textPrimary)

                        if let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                            Text("v\(v)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(themeManager.currentTheme.accentColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(themeManager.currentTheme.accentColor.opacity(0.15)))
                                .overlay(Capsule().stroke(themeManager.currentTheme.accentColor.opacity(0.3), lineWidth: 0.8))
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        // Theme Switcher Button
                        Button(action: { showThemeSheet = true }) {
                            Image(systemName: "paintpalette.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(themeManager.currentTheme.accentColor)
                                .padding(8)
                                .background(Circle().fill(.ultraThinMaterial))
                                .overlay(Circle().stroke(BayanTokens.glassGoldStroke, lineWidth: 1))
                        }

                        // Standalone Status Pill
                        Button(action: { showConnectSheet = true }) {
                            LiquidGlassPill(
                                text: api.runMode == .onDevice ? "Standalone" : (api.isConnected ? "Connected" : "Connect PC"),
                                icon: api.runMode == .onDevice ? "bolt.shield.fill" : (api.isConnected ? "wifi" : "wifi.exclamationmark"),
                                tintColor: api.runMode == .onDevice ? themeManager.currentTheme.accentColor : (api.isConnected ? .green : .orange),
                                isGold: api.runMode == .onDevice
                            )
                        }
                    }
                }
            }
            .sheet(isPresented: $showThemeSheet) {
                ThemePickerSheet()
            }
            .sheet(isPresented: $showConnectSheet) {
                ServerConnectSheet()
            }
            .sheet(isPresented: $showHookDoctorSheet) {
                HookDoctorSheet(originalTitle: storyTitle, originalStory: storyText) { newTitle, newOpening in
                    self.storyTitle = newTitle
                    if !storyText.lowercased().contains(newOpening.lowercased().prefix(25)) {
                        self.storyText = "\(newOpening)\n\n\(storyText)"
                    }
                    triggerAnalysis()
                }
            }
            .sheet(item: Binding<GenerationResult?>(
                get: { generatedResult },
                set: { generatedResult = $0 }
            )) { result in
                VideoPlayerSheet(result: result)
            }
            .onChange(of: selectedPhotoItem) { newItem in
                handlePhotoSelection(newItem)
            }
            .onAppear {
                if storyText.isEmpty {
                    loadCuratedStories()
                }
            }
        }
    }

    // MARK: - Top Header Section
    private var topHeaderSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("AI VIDEO CREATOR")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.currentTheme.accentColor)
                    .tracking(1.0)
                Text("Viral TikTok & Shorts Studio")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.currentTheme.textPrimary)
            }

            Spacer()

            LiquidGlassPill(text: "9:16 Vertical", icon: "iphone.gen3", isGold: true)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Mode Switcher Capsule
    private var modeSwitcherCapsule: some View {
        HStack(spacing: 6) {
            modeButton(mode: .onDevice, title: "📱 Standalone (iPhone)", subtitle: "No PC Needed")
            modeButton(mode: .remotePC, title: "💻 PC Server", subtitle: "Local Wi-Fi")
        }
        .padding(4)
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

    private func modeButton(mode: AppRunMode, title: String, subtitle: String) -> some View {
        let isSelected = api.runMode == mode

        return Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                api.runMode = mode
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? themeManager.currentTheme.ctaTextColor : themeManager.currentTheme.textPrimary.opacity(0.85))
                Text(subtitle)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(isSelected ? themeManager.currentTheme.ctaTextColor.opacity(0.8) : themeManager.currentTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(themeManager.currentTheme.ctaGradient)
                            .shadow(color: themeManager.currentTheme.accentColor.opacity(0.35), radius: 6, y: 2)
                    } else {
                        Color.clear
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Source Selector Bar
    private var sourceSelectorBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SourceType.allCases) { src in
                    let isSelected = selectedSource == src

                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedSource = src
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: src.icon)
                                .font(.system(size: 12, weight: .bold))
                            Text(src.rawValue)
                                .font(.system(size: 12, weight: isSelected ? .bold : .semibold, design: .rounded))
                        }
                        .foregroundColor(isSelected ? themeManager.currentTheme.ctaTextColor : themeManager.currentTheme.textPrimary.opacity(0.85))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            ZStack {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(themeManager.currentTheme.ctaGradient)
                                        .shadow(color: themeManager.currentTheme.accentColor.opacity(0.35), radius: 8, y: 3)
                                } else {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(themeManager.currentTheme.cardBackground)
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(themeManager.currentTheme.cardStroke, lineWidth: 1)
                                }
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Active Source Subviews
    private var activeSourceControls: some View {
        Group {
            switch selectedSource {
            case .curated:
                curatedStoriesSubView
            case .reddit:
                redditSubView
            case .ai:
                aiWriterSubView
            case .quora:
                quoraSubView
            case .youtube:
                youtubeSubView
            case .custom:
                EmptyView()
            }
        }
    }

    // Curated Stories Carousel
    private var curatedStoriesSubView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("🔥 Top High-Retention Scripts")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.currentTheme.accentColor)
                Spacer()
                Text("1-Tap Select")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(themeManager.currentTheme.textSecondary)
            }

            let stories = [
                ("garlic", "Wedding Garlic Bread Drama", "My sister claimed to be severely allergic to garlic for three years until I caught her eating garlic bread..."),
                ("monitor", "Vintage Baby Monitor Mystery", "I bought a vintage baby monitor at a garage sale, but it's picking up a room that doesn't exist..."),
                ("script", "Automated Boss Out of a Job", "My corporate boss stole my $15,000 bonus, so I secretly automated his entire department in Python..."),
                ("parking", "Entitled Neighbor Tow Revenge", "My neighbor kept parking his truck across three spaces until I found a city fire ordinance..."),
                ("heist", "Antwerp Diamond Center Heist", "How Italian masterminds pulled off the impossible $50,000,000 heist using women's hairspray...")
            ]

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(stories, id: \.0) { item in
                        Button(action: {
                            loadSpecificCuratedStory(item.0)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(item.1)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(themeManager.currentTheme.textPrimary)
                                    .lineLimit(1)
                                Text(item.2)
                                    .font(.system(size: 10))
                                    .foregroundColor(themeManager.currentTheme.textSecondary)
                                    .lineLimit(2)
                            }
                            .padding(10)
                            .frame(width: 200, alignment: .leading)
                            .background(
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(themeManager.currentTheme.cardBackground)
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(themeManager.currentTheme.cardStroke, lineWidth: 1)
                                }
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .liquidGlassCard(cornerRadius: 20, isGoldBorder: true)
    }

    // Reddit Subview
    private var redditSubView: some View {
        VStack(spacing: 12) {
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(themeManager.currentTheme.textSecondary)
                    TextField("Subreddit (e.g. AmItheAsshole)", text: $subreddit)
                        .font(.system(size: 13))
                        .foregroundColor(themeManager.currentTheme.textPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(10)
                .background(Color.black.opacity(0.30))
                .cornerRadius(10)

                Button(action: loadRedditStories) {
                    HStack(spacing: 4) {
                        if isLoadingSource {
                            ProgressView().tint(themeManager.currentTheme.ctaTextColor)
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Scrub")
                                .font(.system(size: 12, weight: .bold))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(themeManager.currentTheme.ctaGradient)
                    .foregroundColor(themeManager.currentTheme.ctaTextColor)
                    .cornerRadius(10)
                }
            }

            if !redditStories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(redditStories.prefix(5)) { item in
                            StoryCardView(story: item, isSelected: storyTitle == item.title) {
                                selectStory(item.title, item.story)
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .liquidGlassCard(cornerRadius: 20)
    }

    // AI Writer Subview
    private var aiWriterSubView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Select Category")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.currentTheme.accentColor)
                Spacer()
                Picker("Theme", selection: $aiCategory) {
                    Text("🔥 AITA & Drama").tag("aita")
                    Text("💀 Petty Revenge").tag("revenge")
                    Text("👻 Creepypasta & Horror").tag("scary")
                    Text("🤫 Taboo Confessions").tag("confession")
                    Text("🧠 Dark Psychology Hacks").tag("lifehack")
                    Text("🌌 Shower Thoughts").tag("showerthoughts")
                    Text("🕵️ True Crime & Heists").tag("crime")
                }
                .pickerStyle(.menu)
                .tint(themeManager.currentTheme.accentColor)
            }

            Button(action: generateAIStoryScript) {
                HStack {
                    if isLoadingSource {
                        ProgressView().tint(themeManager.currentTheme.ctaTextColor)
                        Text("Writing Viral Script...")
                    } else {
                        Image(systemName: "wand.and.stars")
                        Text("Write Viral AI Script (60s Hook & Twist)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(themeManager.currentTheme.ctaGradient)
                .foregroundColor(themeManager.currentTheme.ctaTextColor)
                .cornerRadius(12)
            }
        }
        .padding(14)
        .liquidGlassCard(cornerRadius: 20)
    }

    // Quora Subview
    private var quoraSubView: some View {
        HStack {
            TextField("Search topic (e.g. secret hacks)", text: $quoraQuery)
                .font(.system(size: 13))
                .padding(10)
                .background(Color.black.opacity(0.30))
                .cornerRadius(10)
                .foregroundColor(themeManager.currentTheme.textPrimary)

            Button(action: loadQuoraStories) {
                Text("Search")
                    .font(.system(size: 13, weight: .bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(themeManager.currentTheme.ctaGradient)
                    .foregroundColor(themeManager.currentTheme.ctaTextColor)
                    .cornerRadius(10)
            }
        }
        .padding(14)
        .liquidGlassCard(cornerRadius: 20)
    }

    // YouTube Subview
    private var youtubeSubView: some View {
        HStack {
            TextField("Paste YouTube URL", text: $youtubeURL)
                .font(.system(size: 13))
                .padding(10)
                .background(Color.black.opacity(0.30))
                .cornerRadius(10)
                .foregroundColor(themeManager.currentTheme.textPrimary)

            Button(action: loadYouTubeTranscript) {
                Text("Get Script")
                    .font(.system(size: 13, weight: .bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(themeManager.currentTheme.ctaGradient)
                    .foregroundColor(themeManager.currentTheme.ctaTextColor)
                    .cornerRadius(10)
            }
        }
        .padding(14)
        .liquidGlassCard(cornerRadius: 20)
    }

    // MARK: - Story Editor Glass Card
    private var storyEditorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Story Script & Hook")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.currentTheme.textPrimary)

                Spacer()

                // AI Hook Doctor Action Button
                Button(action: {
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    #endif
                    showHookDoctorSheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.badge.automatic.fill")
                        Text("Hook Doctor")
                    }
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(BayanTokens.gold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(BayanTokens.gold.opacity(0.18))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(BayanTokens.gold.opacity(0.4), lineWidth: 0.8))
                }

                // Split Part 1 & Part 2 Button
                if storyText.split(whereSeparator: \.isWhitespace).count >= 70 {
                    Button(action: toggleStorySplit) {
                        HStack(spacing: 4) {
                            Image(systemName: "scissors")
                            Text(storyParts == nil ? "Split Parts" : "Merge")
                        }
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.currentTheme.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(themeManager.currentTheme.accentColor.opacity(0.15))
                        .cornerRadius(8)
                    }
                }

                LiquidGlassPill(text: wordCountText, icon: "clock.fill", isGold: true)
            }

            // Part 1 / Part 2 Segmented Selector (if split active)
            if let parts = storyParts {
                HStack(spacing: 8) {
                    Button(action: { selectPart(1, parts) }) {
                        HStack {
                            Image(systemName: "1.circle.fill")
                            Text("Part 1 (Hook & Cliffhanger)")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(activePart == 1 ? themeManager.currentTheme.accentColor.opacity(0.25) : Color.white.opacity(0.05))
                        .foregroundColor(activePart == 1 ? themeManager.currentTheme.accentColor : themeManager.currentTheme.textSecondary)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(activePart == 1 ? themeManager.currentTheme.accentColor : Color.clear, lineWidth: 1))
                    }

                    Button(action: { selectPart(2, parts) }) {
                        HStack {
                            Image(systemName: "2.circle.fill")
                            Text("Part 2 (The Climax)")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(activePart == 2 ? themeManager.currentTheme.accentColor.opacity(0.25) : Color.white.opacity(0.05))
                        .foregroundColor(activePart == 2 ? themeManager.currentTheme.accentColor : themeManager.currentTheme.textSecondary)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(activePart == 2 ? themeManager.currentTheme.accentColor : Color.clear, lineWidth: 1))
                    }
                }
                .padding(.vertical, 2)
            }

            TextField("Title / Viral Hook (e.g. AITA for uninviting my friend...)", text: $storyTitle)
                .font(.system(size: 14, weight: .bold))
                .padding(12)
                .background(Color.black.opacity(0.30))
                .cornerRadius(10)
                .foregroundColor(themeManager.currentTheme.textPrimary)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1))
                .onChange(of: storyTitle) { _ in triggerAnalysis() }

            TextEditor(text: $storyText)
                .font(.system(size: 13))
                .frame(minHeight: 120, maxHeight: 220)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(Color.black.opacity(0.30))
                .cornerRadius(10)
                .foregroundColor(themeManager.currentTheme.textPrimary)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1))
                .onChange(of: storyText) { _ in triggerAnalysis() }
        }
        .padding(16)
        .liquidGlassCard(cornerRadius: 22, isGoldBorder: true)
    }

    // MARK: - AI Match Holographic Glass Card
    private func aiMatchCard(_ match: AIMatch) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(BayanTokens.gold)
                Text("AI Persona & Tone Match")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(BayanTokens.gold)
                Spacer()
                LiquidGlassPill(text: match.vibe, icon: "waveform", isGold: true)
            }

            Text(match.rationale)
                .font(.system(size: 11))
                .foregroundColor(themeManager.currentTheme.textSecondary)

            HStack(spacing: 6) {
                Label(match.voice_name, systemImage: "mic.fill")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)

                Label(match.bg_name, systemImage: "video.fill")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)

                Label(match.color_name, systemImage: "paintpalette.fill")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
            }
            .foregroundColor(themeManager.currentTheme.textPrimary)
        }
        .padding(14)
        .liquidGlassCard(cornerRadius: 18, isGoldBorder: true)
    }

    // MARK: - Voice, Pacing & B-Roll Controls Card
    private var controlsGlassCard: some View {
        VStack(spacing: 12) {
            // Voice Row with Audio Preview
            controlRow(title: "Voice Actor", icon: "waveform") {
                HStack(spacing: 8) {
                    Picker("Voice", selection: $selectedVoice) {
                        Text("✨ AI Auto-Select (Smart Human)").tag("auto")
                        Text("Ava (Ultra-Human Studio Female)").tag("Ava")
                        Text("Evan (Conversational Male)").tag("Evan")
                        Text("Nathan (Warm Storyteller Male)").tag("Nathan")
                        Text("Zoe (Authentic Expressive Female)").tag("Zoe")
                        Text("Oliver (British Storyteller Male)").tag("Oliver")
                        Text("Samantha (Natural US Female)").tag("Samantha")
                        Text("Andrew (Cloud Neural HD - Male)").tag("en-US-AndrewMultilingualNeural")
                        Text("Ava (Cloud Neural HD - Female)").tag("en-US-AvaMultilingualNeural")
                        Text("Brian (Cloud Neural HD - True Crime)").tag("en-US-BrianMultilingualNeural")
                        Text("Emma (Cloud Neural HD - Witty Female)").tag("en-US-EmmaMultilingualNeural")
                    }
                    .pickerStyle(.menu)
                    .tint(themeManager.currentTheme.accentColor)

                    Button(action: toggleVoicePreview) {
                        Image(systemName: isPlayingVoicePreview ? "stop.circle.fill" : "speaker.wave.2.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(isPlayingVoicePreview ? .red : themeManager.currentTheme.accentColor)
                    }
                }
            }

            Divider().background(Color.white.opacity(0.08))

            // Speed Row
            controlRow(title: "Speech Cadence", icon: "gauge.with.needle.fill") {
                Picker("Speed", selection: $selectedRate) {
                    Text("✨ AI Natural Pacing").tag("auto")
                    Text("Normal (Human 1.0x)").tag("+0%")
                    Text("Conversational (+2%)").tag("+2%")
                    Text("Engaged (+5%)").tag("+5%")
                    Text("Dramatic Slow (-3%)").tag("-3%")
                }
                .pickerStyle(.menu)
                .tint(themeManager.currentTheme.accentColor)
            }

            Divider().background(Color.white.opacity(0.08))

            // Background Music & Audio Ducking
            controlRow(title: "Atmosphere Music", icon: "music.note") {
                Picker("BGM", selection: $selectedBgMusic) {
                    Text("✨ Cinematic Ambient Glow").tag("cinematic_ambient")
                    Text("⚡ Dramatic Suspense").tag("dramatic_suspense")
                    Text("🔥 Viral Synth Pulse").tag("viral_pulse")
                    Text("🔇 None (Narration Only)").tag("none")
                }
                .pickerStyle(.menu)
                .tint(themeManager.currentTheme.accentColor)
            }

            // Audio Mixing Dual Sliders
            VStack(spacing: 6) {
                HStack {
                    Text("Voiceover: \(Int(voiceVolume * 100))%")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme.textSecondary)
                    Slider(value: $voiceVolume, in: 0.5...1.5, step: 0.05)
                        .tint(themeManager.currentTheme.accentColor)
                }

                if selectedBgMusic != "none" {
                    HStack {
                        Text("Music Duck: \(Int(bgMusicVolume * 100))%")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(themeManager.currentTheme.textSecondary)
                        Slider(value: $bgMusicVolume, in: 0.0...0.40, step: 0.02)
                            .tint(themeManager.currentTheme.accentColor)
                    }
                }
            }
            .padding(.horizontal, 4)

            Divider().background(Color.white.opacity(0.08))

            // Subtitle Style Row
            controlRow(title: "Subtitle Color", icon: "captions.bubble.fill") {
                Picker("Style", selection: $selectedColor) {
                    Text("✨ AI Auto-Style").tag("auto")
                    Text("Royal Gold (Bayan)").tag("&H0061BDE6&")
                    Text("TikTok Yellow").tag("&H00FFFF&")
                    Text("Neon Lime Green").tag("&H00FF00&")
                    Text("Electric Cyan").tag("&HFFFF00&")
                    Text("Hot Coral Red").tag("&H0000FF&")
                }
                .pickerStyle(.menu)
                .tint(themeManager.currentTheme.accentColor)
            }

            // Subtitle Position & Typography Size
            controlRow(title: "Subtitle Placement", icon: "arrow.up.and.down.and.sparkles") {
                Picker("Position", selection: $subtitlePosition) {
                    Text("Lower Third (TikTok Safe)").tag("lower")
                    Text("Center Screen (Focus)").tag("center")
                    Text("Upper Screen").tag("upper")
                }
                .pickerStyle(.menu)
                .tint(themeManager.currentTheme.accentColor)
            }

            controlRow(title: "Subtitle Font Size", icon: "textformat.size") {
                Picker("Font Size", selection: $subtitleFontSize) {
                    Text("Standard (52pt)").tag(52.0)
                    Text("Large (64pt)").tag(64.0)
                    Text("Giant (76pt)").tag(76.0)
                }
                .pickerStyle(.menu)
                .tint(themeManager.currentTheme.accentColor)
            }

            Divider().background(Color.white.opacity(0.08))

            // Background Row
            controlRow(title: "B-Roll Footage", icon: "film.fill") {
                Picker("Background", selection: $selectedBackground) {
                    Text("✨ AI Auto-Select").tag("auto")
                    Section("🎮 Gaming Viral") {
                        Text("Minecraft Parkour (9:16)").tag("minecraft_parkour")
                        Text("Subway Surfers Fast Run").tag("subway_surfers")
                        Text("GTA V Mega Ramp Stunts").tag("gta_stunts")
                        Text("BeamNG Car Crashes").tag("beamng_crashes")
                        Text("Roblox Tower Obby").tag("roblox_obby")
                        Text("Temple Run 2 Classic").tag("temple_run")
                        Text("CS:GO / CS2 Smooth Surf").tag("csgo_surf")
                    }
                    Section("🧼 Satisfying ASMR") {
                        Text("Kinetic Sand & Soap ASMR").tag("satisfying_asmr")
                        Text("Hydraulic Press Crushing").tag("hydraulic_press")
                        Text("Slime Crunch ASMR").tag("slime_asmr")
                        Text("Gravity Marble Run").tag("marble_run")
                    }
                    Section("🌌 Aesthetic & Procedural (100% Offline)") {
                        Text("Cyberpunk Synthwave Drive").tag("synthwave_drive")
                        Text("Neon Cyber Grid (AI Procedural)").tag("neon_motion")
                        Text("Dark Atmospheric Smoke (AI Procedural)").tag("dark_cinematic")
                        Text("Cosmic Starfield Warp (AI Procedural)").tag("cosmic_warp")
                        Text("Crimson Suspense Pulse (AI Procedural)").tag("crimson_pulse")
                    }
                }
                .pickerStyle(.menu)
                .tint(themeManager.currentTheme.accentColor)
            }

            // Photos Picker Button
            HStack {
                PhotosPicker(selection: $selectedPhotoItem, matching: .videos) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.badge.plus.fill")
                        Text("Pick Video From iPhone Photos")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(themeManager.currentTheme.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(themeManager.currentTheme.accentColor.opacity(0.12))
                    .cornerRadius(10)
                }

                if api.customBackgroundURL != nil {
                    Spacer()
                    HStack(spacing: 4) {
                        Text("📹 Custom Active")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.green)
                        Button(action: {
                            api.customBackgroundURL = nil
                            selectedPhotoItem = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .liquidGlassCard(cornerRadius: 22)
    }

    private func controlRow<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(themeManager.currentTheme.accentColor)
                .frame(width: 20)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(themeManager.currentTheme.textPrimary)
            Spacer()
            content()
        }
    }

    // MARK: - Generate Section
    private var generateSection: some View {
        VStack(spacing: 12) {
            if api.isGenerating {
                VStack(spacing: 8) {
                    ProgressView(value: api.generationPercent, total: 1.0)
                        .tint(themeManager.currentTheme.accentColor)
                    HStack {
                        Text(api.generationProgressText)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(themeManager.currentTheme.accentColor)
                        Spacer()
                        Text("\(Int(api.generationPercent * 100))%")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(themeManager.currentTheme.textPrimary)
                    }
                }
                .padding(14)
                .liquidGlassCard(cornerRadius: 16)
            }

            GlowingLiquidCTA(
                title: "GENERATE VIRAL TIKTOK VIDEO",
                subtitle: api.runMode == .onDevice ? "⚡ 100% On-Device • Auto-Saves to Camera Roll" : "💻 Fast Server Rendering",
                isLoading: api.isGenerating,
                progressText: api.generationProgressText,
                action: startGeneration
            )
            .disabled(api.isGenerating || storyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .padding(8)
                    .background(Color.red.opacity(0.12))
                    .cornerRadius(8)
            }
        }
    }

    // MARK: - Logic Helpers
    private var wordCountText: String {
        let words = storyText.split(whereSeparator: \.isWhitespace).count
        let seconds = Int(round((Double(words) / 165.0) * 60.0))
        return "\(words) words (~\(seconds)s)"
    }

    private func selectStory(_ title: String, _ text: String) {
        self.storyTitle = title
        self.storyText = text
        triggerAnalysis()
    }

    private func triggerAnalysis() {
        analyzeTask?.cancel()
        guard storyText.count > 25 else { return }
        analyzeTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            do {
                let match = try await api.analyzeStory(story: storyText, title: storyTitle)
                self.aiMatch = match
            } catch {
                // Silently ignore
            }
        }
    }

    private func handlePhotoSelection(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        Task {
            if let movie = try? await item.loadTransferable(type: MovieFile.self) {
                await MainActor.run {
                    api.customBackgroundURL = movie.url
                    customBgFilename = movie.url.lastPathComponent
                }
            }
        }
    }

    private func loadCuratedStories() {
        loadSpecificCuratedStory("garlic")
    }

    private func loadSpecificCuratedStory(_ key: String) {
        if key == "garlic" {
            selectStory(
                "AITA for revealing my sister's fake allergy at her own wedding dinner?",
                "My sister claimed to be severely allergic to garlic for three years until I caught her eating garlic bread at an Italian restaurant. Yesterday at her wedding reception, she started screaming at the coordinator over garlic potatoes. I took the microphone, congratulated the bride, and played the video of her eating garlic bread. Half the family walked out. Am I the jerk?"
            )
        } else if key == "monitor" {
            selectStory(
                "I bought a vintage baby monitor, but it's picking up a room that doesn't exist.",
                "Three weeks ago I set up a vintage audio baby monitor in my daughter's nursery. At 3:14 AM on Thursday, the speaker clicked on with static, followed by a rocking chair slowly creaking on wooden floorboards. My daughter's room has carpet. When I ran in, she was asleep, but the receiver whispered: 'Hush now, he's looking through the door.' The monitor had no batteries inside."
            )
        } else if key == "script" {
            selectStory(
                "My boss stole my bonus, so I accidentally automated his entire job in Python.",
                "My corporate manager took our entire departmental bonus pool and assigned it to himself under 'executive optimization.' I didn't get mad. I opened Python. Over three weeks, I built five scripts that handled every single task he was responsible for: invoice approval, vendor reordering, and weekly charts. During the executive board meeting, the VP asked why the company was paying him two hundred thousand a year when a ten-line script did his job in eight seconds. He was fired before lunch."
            )
        } else if key == "parking" {
            selectStory(
                "My neighbor kept parking his truck across three spaces, so I called the city.",
                "An entitled guy parked his lifted pickup truck diagonally across three assigned spaces for six months. When polite notes were left, he wrote back: 'Call a tow truck if you're broke.' I found a city fire-code ordinance that bans modified bumpers from blocking sprinkler access points in subterranean garages. I submitted timestamped photos. Two days later, three city code officers seized his truck and issued twelve thousand dollars in retroactive penalties. He now rides a lime scooter."
            )
        } else {
            selectStory(
                "The genius heist of the Antwerp Diamond Center where fifty million was stolen without an alarm.",
                "In February 2003, Italian masterminds pulled off the most impossible heist in modern history. The Antwerp Diamond Vault was protected by Doppler radar, seismic sensors, an infrared heat curtain, and magnetic triggers. On the night of the heist, the team bypassed the infrared sensors using ordinary women's hairspray to coat the thermal mirrors. They walked out with fifty million dollars in uncut diamonds and not a single diamond has ever been found."
            )
        }
    }

    private func loadRedditStories() {
        Task {
            isLoadingSource = true
            do {
                let list = try await api.fetchRedditStories(subreddit: subreddit)
                self.redditStories = list
                if let first = list.first {
                    selectStory(first.title, first.story)
                }
            } catch {
                errorMessage = "Reddit error: \(error.localizedDescription)"
            }
            isLoadingSource = false
        }
    }

    private func loadQuoraStories() {
        Task {
            isLoadingSource = true
            do {
                let list = try await api.fetchQuoraStories(query: quoraQuery)
                self.quoraStories = list
                if let first = list.first {
                    selectStory(first.title, first.story)
                }
            } catch {
                errorMessage = "Quora error: \(error.localizedDescription)"
            }
            isLoadingSource = false
        }
    }

    private func loadYouTubeTranscript() {
        guard !youtubeURL.isEmpty else { return }
        Task {
            isLoadingSource = true
            do {
                let story = try await api.fetchYouTubeTranscript(url: youtubeURL)
                selectStory(story.title, story.story)
            } catch {
                errorMessage = "YouTube error: \(error.localizedDescription)"
            }
            isLoadingSource = false
        }
    }

    private func generateAIStoryScript() {
        Task {
            isLoadingSource = true
            do {
                let story = try await api.generateAIStory(category: aiCategory, prompt: aiPrompt, duration: aiDuration)
                selectStory(story.title, story.story)
            } catch {
                errorMessage = "AI story error: \(error.localizedDescription)"
            }
            isLoadingSource = false
        }
    }

    private func toggleStorySplit() {
        if storyParts != nil {
            storyParts = nil
        } else {
            let parts = ViralStoryIntelligence.shared.splitStoryIntoParts(title: storyTitle, story: storyText)
            if parts.isSplittable {
                self.storyParts = parts
                selectPart(1, parts)
            }
        }
    }

    private func selectPart(_ part: Int, _ parts: StoryParts) {
        activePart = part
        if part == 1 {
            self.storyTitle = parts.part1Title
            self.storyText = parts.part1Story
        } else {
            self.storyTitle = parts.part2Title
            self.storyText = parts.part2Story
        }
        triggerAnalysis()
    }

    private func toggleVoicePreview() {
        if isPlayingVoicePreview {
            NativeSpeechService.shared.stopVoicePreview()
            isPlayingVoicePreview = false
        } else {
            isPlayingVoicePreview = true
            NativeSpeechService.shared.previewVoice(voiceId: selectedVoice)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                isPlayingVoicePreview = false
            }
        }
    }

    private func startGeneration() {
        errorMessage = nil
        Task {
            do {
                let res = try await api.generateVideo(
                    title: storyTitle.isEmpty ? "Viral TikTok Story" : storyTitle,
                    story: storyText,
                    voice: selectedVoice,
                    rate: selectedRate,
                    background: selectedBackground,
                    subtitleStyle: "auto",
                    highlightColor: selectedColor,
                    subtitlePosition: subtitlePosition,
                    fontSize: subtitleFontSize,
                    bgMusic: selectedBgMusic,
                    voiceVolume: voiceVolume,
                    bgMusicVolume: bgMusicVolume
                )
                self.generatedResult = res
            } catch {
                self.errorMessage = "Render error: \(error.localizedDescription)"
            }
        }
    }
}
