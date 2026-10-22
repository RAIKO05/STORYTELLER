import SwiftUI

public struct CreatorView: View {
    @ObservedObject var api = StoryTellerAPIService.shared

    // Story Source Selection
    enum SourceType: String, CaseIterable, Identifiable {
        case reddit = "Reddit"
        case quora = "Quora"
        case youtube = "YouTube"
        case ai = "AI Writer"
        case custom = "Custom"
        public var id: String { rawValue }
    }

    @State private var selectedSource: SourceType = .reddit
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
                        // Connection Header
                        connectionPill

                        // 1. Source Segmented Control
                        sourcePickerSection

                        // 2. Active Story Editor
                        storyEditorSection

                        // 3. AI Story & Voice Matcher Banner
                        if let match = aiMatch {
                            aiMatchCard(match)
                        }

                        // 4. Voice & Background Controls
                        controlsSection

                        // 5. Generate CTA Button
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
                                .fill(api.isConnected ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(api.isConnected ? "PC Connected" : "Connect PC")
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
            .onAppear {
                Task {
                    _ = await api.pingServer()
                    if redditStories.isEmpty {
                        loadRedditStories()
                    }
                }
            }
        }
    }

    // Connection Pill
    private var connectionPill: some View {
        HStack {
            Image(systemName: "video.fill")
                .foregroundColor(.cyan)
            Text("Viral TikTok & Shorts Studio")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
            Spacer()
            Text("9:16 Vertical")
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.purple.opacity(0.2))
                .foregroundColor(.purple)
                .cornerRadius(8)
        }
        .padding(.vertical, 8)
    }

    // Source Picker
    private var sourcePickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Source", selection: $selectedSource) {
                ForEach(SourceType.allCases) { src in
                    Text(src.rawValue).tag(src)
                }
            }
            .pickerStyle(.segmented)

            switch selectedSource {
            case .reddit:
                redditSubSection
            case .quora:
                quoraSubSection
            case .youtube:
                youtubeSubSection
            case .ai:
                aiWriterSubSection
            case .custom:
                EmptyView()
            }
        }
        .padding(14)
        .background(Color(red: 0.08, green: 0.10, blue: 0.15))
        .cornerRadius(14)
    }

    // Reddit Controls
    private var redditSubSection: some View {
        VStack(spacing: 10) {
            HStack {
                Picker("Subreddit", selection: $subreddit) {
                    Text("r/AmItheAsshole").tag("AmItheAsshole")
                    Text("r/tifu").tag("tifu")
                    Text("r/confession").tag("confession")
                    Text("r/AskReddit").tag("AskReddit")
                    Text("r/maliciouscompliance").tag("maliciouscompliance")
                }
                .pickerStyle(.menu)
                .tint(.cyan)

                Spacer()

                Button("Fetch Stories", action: loadRedditStories)
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.cyan.opacity(0.15))
                    .foregroundColor(.cyan)
                    .cornerRadius(8)
            }

            if !redditStories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(redditStories) { s in
                            StoryCardView(story: s, isSelected: storyTitle == s.title) {
                                selectStory(s.title, s.story)
                            }
                            .frame(width: 260)
                        }
                    }
                }
            }
        }
    }

    // Quora Controls
    private var quoraSubSection: some View {
        VStack(spacing: 10) {
            HStack {
                TextField("Search Quora topic...", text: $quoraQuery)
                    .textFieldStyle(.roundedBorder)
                Button("Search", action: loadQuoraStories)
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.purple.opacity(0.2))
                    .foregroundColor(.purple)
                    .cornerRadius(8)
            }

            if !quoraStories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(quoraStories) { s in
                            StoryCardView(story: s, isSelected: storyTitle == s.title) {
                                selectStory(s.title, s.story)
                            }
                            .frame(width: 260)
                        }
                    }
                }
            }
        }
    }

    // YouTube Controls
    private var youtubeSubSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YouTube URL (Transcripts auto-extracted)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.gray)
            HStack {
                TextField("https://www.youtube.com/watch?v=...", text: $youtubeURL)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.URL)
                Button("Extract", action: loadYouTubeTranscript)
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.2))
                    .foregroundColor(.red)
                    .cornerRadius(8)
            }
        }
    }

    // AI Writer Controls
    private var aiWriterSubSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Picker("Category", selection: $aiCategory) {
                    Text("Moral Dilemma (AITA)").tag("aita")
                    Text("Sweet Revenge").tag("revenge")
                    Text("Deep Confession").tag("confession")
                    Text("Mystery / Creepypasta").tag("mystery")
                }
                .pickerStyle(.menu)
                .tint(.purple)

                Spacer()

                Button("✨ Generate Script", action: generateAIStoryScript)
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
    }

    // Active Story Editor
    private var storyEditorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ACTIVE SCRIPT")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                Spacer()
                Text(wordCountText)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.cyan.opacity(0.15))
                    .foregroundColor(.cyan)
                    .cornerRadius(6)
            }

            TextField("Viral Hook Title...", text: $storyTitle)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .padding(10)
                .background(Color(red: 0.05, green: 0.07, blue: 0.11))
                .cornerRadius(8)
                .onChange(of: storyTitle) { _ in triggerAnalysis() }

            TextEditor(text: $storyText)
                .frame(minHeight: 120)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .padding(6)
                .background(Color(red: 0.05, green: 0.07, blue: 0.11))
                .cornerRadius(8)
                .scrollContentBackground(.hidden)
                .onChange(of: storyText) { _ in triggerAnalysis() }
        }
        .padding(14)
        .background(Color(red: 0.08, green: 0.10, blue: 0.15))
        .cornerRadius(14)
    }

    // AI Match Card
    private func aiMatchCard(_ match: AIMatch) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("🤖 AI Match: \(match.vibe)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.cyan)
                Spacer()
                Button("✨ Apply AI Match") {
                    selectedVoice = match.recommended_voice
                    selectedRate = match.recommended_rate
                    selectedBackground = match.recommended_bg
                    selectedColor = match.recommended_color
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(6)
            }

            Text(match.rationale)
                .font(.system(size: 11))
                .foregroundColor(.gray)

            HStack(spacing: 8) {
                Label(match.voice_name, systemImage: "waveform")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.15))
                    .foregroundColor(.green)
                    .cornerRadius(4)

                Label(match.bg_name, systemImage: "film")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.cyan.opacity(0.15))
                    .foregroundColor(.cyan)
                    .cornerRadius(4)

                Label(match.recommended_rate, systemImage: "bolt.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .cornerRadius(4)
            }
        }
        .padding(12)
        .background(LinearGradient(colors: [Color.purple.opacity(0.12), Color.cyan.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.3), lineWidth: 1))
    }

    // Customization Controls
    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AUDIO & VIDEO STYLING")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)

            // Voice Picker
            HStack {
                Text("Narrator Voice")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                Picker("Voice", selection: $selectedVoice) {
                    Text("✨ AI Auto-Select").tag("auto")
                    Text("Christopher (Deep Storyteller)").tag("en-US-ChristopherNeural")
                    Text("Guy (Energetic Viral)").tag("en-US-GuyNeural")
                    Text("Jenny (Natural Female)").tag("en-US-JennyNeural")
                    Text("Aria (Dramatic Female)").tag("en-US-AriaNeural")
                    Text("Eric (True Crime Mystery)").tag("en-US-EricNeural")
                    Text("Ryan (British Narrator)").tag("en-GB-RyanNeural")
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
                    Text("Steady (+8%)").tag("+8%")
                    Text("Snappy (+12%)").tag("+12%")
                    Text("Viral High (+18%)").tag("+18%")
                }
                .pickerStyle(.menu)
                .tint(.cyan)
            }

            // Background Picker
            HStack {
                Text("B-Roll Footage")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                Picker("Background", selection: $selectedBackground) {
                    Text("✨ AI Auto-Scrub").tag("auto")
                    Section("🎮 Gaming Viral") {
                        Text("Minecraft Parkour (9:16)").tag("minecraft_parkour")
                        Text("Subway Surfers Fast Run").tag("subway_surfers")
                        Text("GTA V Mega Ramp Stunts").tag("gta_stunts")
                        Text("BeamNG Car Crashes").tag("beamng_crashes")
                        Text("Roblox Tower Obby").tag("roblox_obby")
                        Text("Temple Run 2 Classic").tag("temple_run")
                    }
                    Section("🧼 Satisfying ASMR") {
                        Text("Kinetic Sand & Soap Cutting").tag("satisfying_asmr")
                        Text("Hydraulic Press Crushing").tag("hydraulic_press")
                        Text("Power Washing Deep Clean").tag("power_washing")
                    }
                    Section("🌌 Aesthetic & Procedural") {
                        Text("Cyberpunk Synthwave Drive").tag("synthwave_drive")
                        Text("Dark Atmospheric Mystery (AI)").tag("dark_cinematic")
                        Text("Space Galaxy & Aurora (AI)").tag("aurora_galaxy")
                        Text("Neon Cyber Grid (AI)").tag("neon_motion")
                    }
                }
                .pickerStyle(.menu)
                .tint(.cyan)
            }
        }
        .padding(14)
        .background(Color(red: 0.08, green: 0.10, blue: 0.15))
        .cornerRadius(14)
    }

    // Generate CTA
    private var generateButtonSection: some View {
        VStack(spacing: 8) {
            Button(action: startGeneration) {
                HStack {
                    if api.isGenerating {
                        ProgressView().tint(.black)
                        Text(api.generationProgressText)
                            .fontWeight(.bold)
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

    // Logic Helpers
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
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }
            do {
                let match = try await api.analyzeStory(story: storyText, title: storyTitle)
                self.aiMatch = match
            } catch {
                // Silently ignore offline
            }
        }
    }

    private func loadRedditStories() {
        Task {
            isLoadingSource = true
            do {
                let list = try await api.fetchRedditStories(subreddit: subreddit)
                self.redditStories = list
                if let first = list.first, storyText.isEmpty {
                    selectStory(first.title, first.story)
                }
            } catch {
                errorMessage = "Failed to load Reddit: \(error.localizedDescription)"
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
                errorMessage = "Failed to load Quora: \(error.localizedDescription)"
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
                errorMessage = "Transcript fetch error: \(error.localizedDescription)"
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
