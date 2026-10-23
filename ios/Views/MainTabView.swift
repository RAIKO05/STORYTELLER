import SwiftUI

public struct MainTabView: View {
    @ObservedObject var api = StoryTellerAPIService.shared
    @ObservedObject private var themeManager = AppThemeManager.shared
    @State private var selectedTab: TabItem = .studio
    @Namespace private var tabNamespace

    public enum TabItem: Int, CaseIterable, Identifiable {
        case studio = 0
        case gallery = 1
        case themes = 2
        case connect = 3

        public var id: Int { rawValue }

        public var title: String {
            switch self {
            case .studio: return "Studio"
            case .gallery: return "Gallery"
            case .themes: return "Themes"
            case .connect: return "Connect"
            }
        }

        public var icon: String {
            switch self {
            case .studio: return "wand.and.stars"
            case .gallery: return "play.rectangle.on.rectangle.fill"
            case .themes: return "paintpalette.fill"
            case .connect: return "wifi"
            }
        }
    }

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            // Theme Background Canvas
            themeManager.currentTheme.backgroundColor.ignoresSafeArea()
            themeManager.currentTheme.backgroundGradient.ignoresSafeArea()

            // Main Content Area
            Group {
                switch selectedTab {
                case .studio:
                    CreatorView()
                case .gallery:
                    GalleryView()
                case .themes:
                    themeView
                case .connect:
                    ServerConnectSheet()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Bayan-Inspired Floating Capsule Navigation Dock
            floatingCapsuleTabBar
        }
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - Dedicated Theme & Atmosphere Tab
    private var themeView: some View {
        NavigationStack {
            ZStack {
                LiquidMeshBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        AppThemeSelectorCard()

                        // Luxury Atmosphere Details
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "sparkles.rectangle.stack.fill")
                                    .foregroundColor(themeManager.currentTheme.accentColor)
                                Text("Dynamic Specular Engine")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(themeManager.currentTheme.textPrimary)
                            }

                            Text("StoryTeller adopts the Bayan luxury aesthetic: deep obsidian canvas, emerald ambient glows, shimmering royal gold (#E6BD61) specular rim highlights, and frosted ultra-thin liquid glass.")
                                .font(.system(size: 12))
                                .foregroundColor(themeManager.currentTheme.textSecondary)
                                .lineSpacing(3)

                            Divider().background(Color.white.opacity(0.08))

                            HStack {
                                Text("Active Theme:")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(themeManager.currentTheme.textSecondary)
                                Spacer()
                                LiquidGlassPill(text: themeManager.currentTheme.title, icon: "checkmark.seal.fill", isGold: true)
                            }
                        }
                        .padding(16)
                        .liquidGlassCard(cornerRadius: 22, isGoldBorder: true)

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                }
            }
            .navigationTitle("App Atmosphere")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Bayan Floating Capsule Dock
    private var floatingCapsuleTabBar: some View {
        HStack(spacing: 4) {
            ForEach(TabItem.allCases) { tab in
                let isSelected = selectedTab == tab

                Button {
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.76)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: isSelected ? 18 : 16, weight: isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? themeManager.currentTheme.accentColor : Color.white.opacity(0.60))
                            .frame(height: 24)

                        Text(tab.title)
                            .font(.system(size: 10.5, weight: isSelected ? .bold : .medium, design: .rounded))
                            .foregroundColor(isSelected ? themeManager.currentTheme.textPrimary : Color.white.opacity(0.60))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .contentShape(Rectangle())
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(
                                    themeManager.currentTheme.isDark
                                        ? Color(red: 0.16, green: 0.18, blue: 0.22).opacity(0.95)
                                        : Color.black.opacity(0.08)
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    themeManager.currentTheme.accentColor.opacity(0.6),
                                                    Color.clear
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                            lineWidth: 1.0
                                        )
                                )
                                .matchedGeometryEffect(id: "activeTabPill", in: tabNamespace)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(height: 64)
        .background(
            Capsule()
                .fill(
                    themeManager.currentTheme.isDark
                        ? Color(red: 0.08, green: 0.09, blue: 0.12).opacity(0.92)
                        : Color.white.opacity(0.92)
                )
        )
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [
                            BayanTokens.gold.opacity(0.40),
                            Color.white.opacity(0.12),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: Color.black.opacity(0.40), radius: 20, x: 0, y: 10)
        .shadow(color: themeManager.currentTheme.accentColor.opacity(0.15), radius: 25, x: 0, y: 4)
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }
}
