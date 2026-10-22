import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// Transferable helper for PhotosPicker video selection
struct MovieFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
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

    // Story Source Selection
    enum SourceType: String, CaseIterable, Identifiable {
        case curated = "Curated 🔥"
        case reddit = "Reddit"
        case ai = "AI Writer"
        case quora = "Quora"
        case youtube = "YouTube"
        case custom = "Custom"
        public var id: String { rawValue }
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

    // Generation & Sheets
    @State private var showConnectSheet: Bool = false
    @State private var generatedResult: GenerationResult?
    @State private var errorMessage: String?
    @State private var isLoadingSource: Bool = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.06, blue: 0.09).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 1. Run Mode Switcher (Standalone iPhone vs PC Server)
                        modeSwitcherCard

                        // 2. Source Segmented Control
                        sourcePickerSection

                        // 3. Active Story Editor
                        storyEditorSection

                        // 4. AI Story & Voice Matcher Banner
                        if let match = aiMatch {
                            aiMatchCard(match)
                        }

                        // 5. Voice & Background Controls
                        controlsSection

                        // 6. Generate CTA Button
                        generateButtonSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("StoryTeller AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showConnectSheet = true }) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(api.runMode == .onDevice ? Color.cyan : (api.isConnected ? Color.green : Color.orange))
                                .frame(width: 8, height: 8)
                            Text(api.runMode == .onDevice ? "📱 Standalone" : (api.isConnected ? "PC Connected" : "Connect PC"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(red: 0.12, green: 0.15, blue: 0.22))
                        .cornerRadius(16)
                    }
                }
            }
            .sheet(isPresented: $showConnectSheet) {
                ServerConnectSheet()
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

    // MARK: - Mode Switcher Card
    private var modeSwitcherCard: some View {
        VStack(spacing: 10) {
            Picker("App Mode", selection: $api.runMode) {
                Text("📱 iPhone Standalone").tag(AppRunMode.onDevice)
                Text("💻 PC Server").tag(AppRunMode.remotePC)
            }
            .pickerStyle(.segmented)

            HStack {
                if api.runMode == .onDevice {
                    Image(systemName: "bolt.shield.fill")
                        .foregroundColor(.cyan)
                    Text("100% On-Device • No PC or Wi-Fi Needed")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.cyan)
                } else {
                    Image(systemName: api.isConnected ? "wifi" : "wifi.exclamationmark")
                        .foregroundColor(api.isConnected ? .green : .orange)
                    Text(api.isConnected ? "Connected to PC Studio" : "PC Server Offline - Tap top bar to connect")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(api.isConnected ? .green : .orange)
                }
                Spacer()
                Text("9:16 1080p")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.3))
                    .foregroundColor(.purple)
                    .cornerRadius(6)
            }
        }
        .padding(12)
        .background(Color(red: 0.08, green: 0.10, blue: 0.16))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(api.runMode == .onDevice ? Color.cyan.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Source Picker
    private var sourcePickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Source", selection: $selectedSource) {
                ForEach(SourceType.allCases) { src in
                    Text(src.rawValue).tag(src)
                }
            }
            .pickerStyle(.segmented)

            // Source Specific Controls
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
        .padding(14)
        .background(Color(red: 0.08, green: 0.10, blue: 0.15))
        .cornerRadius(14)
    }

    // Curated Subview
    private var curatedStoriesSubView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Top Viral TikTok Story Scripts (Ready to Generate)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.cyan)

            let stories = [
                ("garlic", "Wedding Garlic Bread Drama", "My sister claimed to be severely allergic to garlic for three years until I caught her eating garlic bread..."),
                ("monitor", "Vintage Baby Monitor Mystery", "I bought a vintage baby monitor at a garage sale, but it's picking up a room that doesn't exist..."),
                ("script", "Automated Boss Out of a Job", "My corporate boss stole my $15,000 bonus, so I secretly automated his entire department in Python..."),
                ("parking", "Entitled Neighbor Tow Revenge", "My neighbor kept parking his truck across three spaces until I found a city fire ordinance..."),
                ("heist", "Antwerp Diamond Center Heist", "How Italian masterminds pulled off the impossible $50,000,000 heist using women's hairspray...")
            ]

            ForEach(stories, id: \.0) { item in
                Button(action: {
                    loadSpecificCuratedStory(item.0)
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.1)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                            Text(item.2)
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(.cyan)
                    }
                    .padding(10)
                    .background(Color(red: 0.12, green: 0.14, blue: 0.20))
                    .cornerRadius(10)
                }
            }
        }
    }

    // Reddit Subview
    private var redditSubView: some View {
        VStack(spacing: 10) {
            HStack {
                TextField("Subreddit (e.g. AmItheAsshole)", text: $subreddit)
                    .font(.system(size: 13))
                    .padding(10)
                    .background(Color(red: 0.12, green: 0.14, blue: 0.20))
                    .cornerRadius(8)
                    .foregroundColor(.white)

                Button(action: loadRedditStories) {
                    if isLoadingSource {
                        ProgressView().tint(.white)
                    } else {
                        Text("Scrub Hot")
                            .font(.system(size: 13, weight: .bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.cyan)
                            .foregroundColor(.black)
                            .cornerRadius(8)
                    }
                }
            }

            if !redditStories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(redditStories.prefix(5)) { item in
                            StoryCardView(story: item) {
                                selectStory(item.title, item.story)
                            }
                        }
                    }
                }
            }
        }
    }

    // AI Writer Subview
    private var aiWriterSubView: some View {
        VStack(alignment: .leading, spacing: 10) {
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
            .tint(.cyan)

            Button(action: generateAIStoryScript) {
                HStack {
                    if isLoadingSource {
                        ProgressView().tint(.black)
                        Text("Writing Viral Script...")
                    } else {
                        Image(systemName: "sparkles")
                        Text("Write Viral AI Script (60s Hook & Twist)")
                            .font(.system(size: 13, weight: .bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.cyan)
                .foregroundColor(.black)
                .cornerRadius(8)
            }
        }
    }

    // Quora Subview
    private var quoraSubView: some View {
        VStack(spacing: 10) {
            HStack {
                TextField("Search topic (e.g. secret hacks)", text: $quoraQuery)
                    .font(.system(size: 13))
                    .padding(10)
                    .background(Color(red: 0.12, green: 0.14, blue: 0.20))
                    .cornerRadius(8)
                    .foregroundColor(.white)

                Button(action: loadQuoraStories) {
                    Text("Search")
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.cyan)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                }
            }
        }
    }

    // YouTube Subview
    private var youtubeSubView: some View {
        VStack(spacing: 10) {
            HStack {
                TextField("Paste YouTube URL", text: $youtubeURL)
                    .font(.system(size: 13))
                    .padding(10)
                    .background(Color(red: 0.12, green: 0.14, blue: 0.20))
                    .cornerRadius(8)
                    .foregroundColor(.white)

                Button(action: loadYouTubeTranscript) {
                    Text("Get Script")
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.cyan)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - Story Editor
    private var storyEditorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Viral Script")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text(wordCountText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.cyan)
            }

            TextField("Title / Viral Hook (e.g. AITA for uninviting my friend...)", text: $storyTitle)
                .font(.system(size: 14, weight: .semibold))
                .padding(10)
                .background(Color(red: 0.12, green: 0.14, blue: 0.20))
                .cornerRadius(8)
                .foregroundColor(.white)
                .onChange(of: storyTitle) { _ in triggerAnalysis() }

            TextEditor(text: $storyText)
                .font(.system(size: 13))
                .frame(minHeight: 120, maxHeight: 180)
                .padding(6)
                .scrollContentBackground(.hidden)
                .background(Color(red: 0.12, green: 0.14, blue: 0.20))
                .cornerRadius(8)
                .foregroundColor(.white)
                .onChange(of: storyText) { _ in triggerAnalysis() }
        }
        .padding(14)
        .background(Color(red: 0.08, green: 0.10, blue: 0.15))
        .cornerRadius(14)
    }

    // MARK: - AI Match Card
    private func aiMatchCard(_ match: AIMatch) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.pink)
                Text("AI Persona & Tone Match")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.pink)
                Spacer()
                Text(match.vibe)
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.pink.opacity(0.2))
                    .foregroundColor(.pink)
                    .cornerRadius(8)
            }

            Text(match.rationale)
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.85, green: 0.88, blue: 0.95))

            HStack(spacing: 8) {
                Label(match.voice_name, systemImage: "waveform")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(6)

                Label(match.bg_name, systemImage: "video")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(6)

                Label(match.color_name, systemImage: "paintpalette")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(6)
            }
            .foregroundColor(.white)
        }
        .padding(12)
        .background(Color(red: 0.13, green: 0.09, blue: 0.15))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.pink.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Voice & Background Controls
    private var controlsSection: some View {
        VStack(spacing: 14) {
            // Voice Picker
            HStack {
                Text("Voice Actor")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                Picker("Voice", selection: $selectedVoice) {
                    Text("✨ AI Auto-Select").tag("auto")
                    Text("Samantha (Natural US)").tag("en-US-Samantha")
                    Text("Daniel (British Narrator)").tag("en-GB-Daniel")
                    Text("Arthur (Deep & Clear)").tag("en-US-Arthur")
                    Text("Karen (Australian)").tag("en-AU-Karen")
                    Text("Fred (Punchy Retro)").tag("en-US-Fred")
                    Text("Christopher (Deep Cloud)").tag("en-US-ChristopherNeural")
                    Text("Guy (Energetic Cloud)").tag("en-US-GuyNeural")
                    Text("Jenny (Female Cloud)").tag("en-US-JennyNeural")
                }
                .pickerStyle(.menu)
                .tint(.cyan)
            }

            // Speed Picker
            HStack {
                Text("Pacing Speed")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                Picker("Speed", selection: $selectedRate) {
                    Text("✨ AI Optimal").tag("auto")
                    Text("Normal (1.0x)").tag("+0%")
                    Text("Snappy (+8%)").tag("+8%")
                    Text("Viral High (+12%)").tag("+12%")
                    Text("Hyper (+18%)").tag("+18%")
                }
                .pickerStyle(.menu)
                .tint(.cyan)
            }

            // Subtitle Style
            HStack {
                Text("Subtitle Style")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                Picker("Style", selection: $selectedColor) {
                    Text("✨ AI Auto-Style").tag("auto")
                    Text("CapCut Karaoke (Yellow)").tag("&H00FFFF&")
                    Text("Neon Lime Green").tag("&H00FF00&")
                    Text("Electric Cyan").tag("&HFFFF00&")
                    Text("Hot Coral Red").tag("&H0000FF&")
                }
                .pickerStyle(.menu)
                .tint(.cyan)
            }

            // Background Picker
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("B-Roll Footage")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
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
                    .tint(.cyan)
                }

                // Photos Picker for Custom Background
                HStack {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .videos) {
                        HStack(spacing: 6) {
                            Image(systemName: "photo.badge.plus")
                            Text("Use Video From My iPhone Photos")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(.cyan)
                        .cornerRadius(8)
                    }

                    if api.customBackgroundURL != nil {
                        Spacer()
                        HStack(spacing: 4) {
                            Text("📷 Custom Video Active")
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
            }
        }
        .padding(14)
        .background(Color(red: 0.08, green: 0.10, blue: 0.15))
        .cornerRadius(14)
    }

    // MARK: - Generate CTA
    private var generateButtonSection: some View {
        VStack(spacing: 12) {
            if api.isGenerating {
                VStack(spacing: 8) {
                    ProgressView(value: api.generationPercent, total: 1.0)
                        .tint(.cyan)
                    Text(api.generationProgressText)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.cyan)
                }
                .padding(14)
                .background(Color(red: 0.08, green: 0.12, blue: 0.20))
                .cornerRadius(12)
            }

            Button(action: startGeneration) {
                HStack(spacing: 8) {
                    if api.isGenerating {
                        ProgressView().tint(.black)
                        Text("RENDERING...")
                            .fontWeight(.black)
                    } else {
                        Image(systemName: "bolt.fill")
                        Text("GENERATE VIRAL TIKTOK VIDEO")
                            .font(.system(size: 14, weight: .heavy))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(LinearGradient(colors: [Color.cyan, Color(red: 0.3, green: 0.7, blue: 1.0), Color.pink], startPoint: .leading, endPoint: .trailing))
                .foregroundColor(.black)
                .cornerRadius(14)
                .shadow(color: .cyan.opacity(0.4), radius: 10, y: 4)
            }
            .disabled(api.isGenerating || storyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
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
            try? await Task.sleep(nanoseconds: 400_000_000)
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
                    highlightColor: selectedColor
                )
                self.generatedResult = res
            } catch {
                self.errorMessage = "Render error: \(error.localizedDescription)"
            }
        }
    }
}
