import SwiftUI

public struct HookDoctorSheet: View {
    public let originalTitle: String
    public let originalStory: String
    public var onSelectHook: (String, String) -> Void

    @ObservedObject private var themeManager = AppThemeManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var hooks: [HookOption] = []
    @State private var selectedIndex: Int? = nil

    public init(
        originalTitle: String,
        originalStory: String,
        onSelectHook: @escaping (String, String) -> Void
    ) {
        self.originalTitle = originalTitle
        self.originalStory = originalStory
        self.onSelectHook = onSelectHook
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                LiquidMeshBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        // Header Banner
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "bolt.badge.automatic.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(BayanTokens.gold)
                                Text("AI VIRAL HOOK DOCTOR")
                                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                                    .foregroundColor(BayanTokens.gold)
                                    .tracking(1.2)
                            }

                            Text("Stop the Scroll in 3 Seconds")
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                                .foregroundColor(themeManager.currentTheme.textPrimary)

                            Text("90% of viral TikTok retention is decided in the first sentence. Select one of the algorithm-optimized hook formulas below:")
                                .font(.system(size: 12))
                                .foregroundColor(themeManager.currentTheme.textSecondary)
                        }
                        .padding(.top, 8)

                        // 3 Hook Cards
                        ForEach(Array(hooks.enumerated()), id: \.element.id) { index, hook in
                            let isChosen = selectedIndex == index

                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(hook.style.uppercased())
                                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                                        .foregroundColor(themeManager.currentTheme.textPrimary)

                                    Spacer()

                                    Text(hook.badge)
                                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                        .foregroundColor(themeManager.currentTheme.accentColor)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(themeManager.currentTheme.accentColor.opacity(0.18))
                                        .cornerRadius(8)
                                }

                                Text("\"\(hook.hookTitle)\"")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(themeManager.currentTheme.accentColor)

                                Text(hook.hookOpening)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(themeManager.currentTheme.textPrimary.opacity(0.92))
                                    .padding(10)
                                    .background(Color.black.opacity(0.35))
                                    .cornerRadius(10)

                                HStack {
                                    Text("💡 \(hook.viralStrategy)")
                                        .font(.system(size: 11))
                                        .foregroundColor(themeManager.currentTheme.textSecondary)

                                    Spacer()

                                    Button(action: {
                                        #if os(iOS)
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        #endif
                                        selectedIndex = index
                                        onSelectHook(hook.hookTitle, hook.hookOpening)
                                        dismiss()
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "checkmark.circle.fill")
                                            Text("Apply Hook")
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(themeManager.currentTheme.ctaGradient)
                                        .foregroundColor(themeManager.currentTheme.ctaTextColor)
                                        .clipShape(Capsule())
                                        .shadow(color: themeManager.currentTheme.accentColor.opacity(0.3), radius: 6)
                                    }
                                }
                            }
                            .padding(16)
                            .liquidGlassCard(cornerRadius: 20, isGoldBorder: isChosen)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(18)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.accentColor)
                    .font(.system(size: 14, weight: .bold))
                }
            }
            .onAppear {
                hooks = ViralStoryIntelligence.shared.generateViralHooks(
                    title: originalTitle,
                    story: originalStory
                )
            }
        }
    }
}
