import SwiftUI

// MARK: - Bayan Color Tokens (Shared Luxury Palette)
public enum BayanTokens {
    // Canvas & Depth
    public static let obsidian = Color(red: 0.04, green: 0.05, blue: 0.07)
    public static let deepEmerald = Color(red: 0.03, green: 0.20, blue: 0.16)
    public static let emeraldGlow = Color(red: 0.08, green: 0.45, blue: 0.35)
    public static let royalNavy = Color(red: 0.05, green: 0.09, blue: 0.18)

    // Royal Accents
    public static let gold = Color(red: 0.90, green: 0.74, blue: 0.38)          // #E6BD61
    public static let goldSoft = Color(red: 0.96, green: 0.88, blue: 0.65)      // #F5E0A6
    public static let goldDark = Color(red: 0.72, green: 0.56, blue: 0.24)
    public static let electricCyan = Color(red: 0.20, green: 0.82, blue: 0.88)  // #33D1E0

    // Glass Rim Strokes
    public static let glassStroke = LinearGradient(
        colors: [
            Color.white.opacity(0.35),
            Color.white.opacity(0.08),
            Color.white.opacity(0.02)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let glassGoldStroke = LinearGradient(
        colors: [
            gold.opacity(0.65),
            gold.opacity(0.25),
            Color.clear
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let glassEmeraldStroke = LinearGradient(
        colors: [
            Color(red: 0.25, green: 0.90, blue: 0.60).opacity(0.60),
            Color(red: 0.08, green: 0.45, blue: 0.35).opacity(0.20),
            Color.clear
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - App Theme Catalog
public enum StoryAppTheme: String, CaseIterable, Identifiable, Codable {
    case obsidian = "Obsidian"
    case emerald = "Deep Emerald"
    case midnight = "Midnight"
    case oled = "Pure OLED"
    case sand = "Imperial Sand"

    public var id: String { rawValue }
    public var title: String { rawValue }

    public var subtitle: String {
        switch self {
        case .obsidian: return "Obsidian Dark & Royal Gold"
        case .emerald: return "Moroccan Emerald & Gold"
        case .midnight: return "Sapphire Midnight & Cyan"
        case .oled: return "Zero-Emissive True Black"
        case .sand: return "Royal Warm Sand & Bronze"
        }
    }

    public var isDark: Bool {
        return self != .sand
    }

    // MARK: - Preview Styling for Theme Selector
    public var previewBackground: Color {
        switch self {
        case .obsidian: return Color(red: 0.08, green: 0.09, blue: 0.12)
        case .emerald: return Color(red: 0.03, green: 0.16, blue: 0.12)
        case .midnight: return Color(red: 0.05, green: 0.09, blue: 0.18)
        case .oled: return Color(red: 0.02, green: 0.02, blue: 0.02)
        case .sand: return Color(red: 0.96, green: 0.93, blue: 0.86)
        }
    }

    public var previewTextColor: Color {
        switch self {
        case .sand: return Color(red: 0.18, green: 0.11, blue: 0.05)
        default: return .white
        }
    }

    public var previewAccentColor: Color {
        switch self {
        case .obsidian: return BayanTokens.gold
        case .emerald: return Color(red: 0.25, green: 0.90, blue: 0.60)
        case .midnight: return BayanTokens.electricCyan
        case .oled: return BayanTokens.goldSoft
        case .sand: return Color(red: 0.72, green: 0.52, blue: 0.20)
        }
    }

    // MARK: - Background Canvas & Gradients
    public var backgroundColor: Color {
        switch self {
        case .obsidian: return BayanTokens.obsidian
        case .emerald: return Color(red: 0.02, green: 0.12, blue: 0.09)
        case .midnight: return Color(red: 0.03, green: 0.06, blue: 0.14)
        case .oled: return Color.black
        case .sand: return Color(red: 0.96, green: 0.93, blue: 0.86)
        }
    }

    public var backgroundGradient: RadialGradient {
        switch self {
        case .obsidian:
            return RadialGradient(
                colors: [BayanTokens.deepEmerald.opacity(0.40), BayanTokens.obsidian],
                center: .top,
                startRadius: 40,
                endRadius: 550
            )
        case .emerald:
            return RadialGradient(
                colors: [Color(red: 0.05, green: 0.28, blue: 0.20), Color(red: 0.02, green: 0.10, blue: 0.08)],
                center: .top,
                startRadius: 50,
                endRadius: 600
            )
        case .midnight:
            return RadialGradient(
                colors: [Color(red: 0.08, green: 0.16, blue: 0.32), Color(red: 0.02, green: 0.05, blue: 0.12)],
                center: .top,
                startRadius: 50,
                endRadius: 600
            )
        case .oled:
            return RadialGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.05), Color.black],
                center: .center,
                startRadius: 40,
                endRadius: 500
            )
        case .sand:
            return RadialGradient(
                colors: [Color(red: 0.99, green: 0.97, blue: 0.92), Color(red: 0.94, green: 0.90, blue: 0.82)],
                center: .top,
                startRadius: 40,
                endRadius: 550
            )
        }
    }

    // Mesh Orbs for Ambient Liquid Animation
    public var meshColors: (Color, Color, Color) {
        switch self {
        case .obsidian:
            return (
                BayanTokens.gold.opacity(0.18),
                BayanTokens.deepEmerald.opacity(0.35),
                BayanTokens.emeraldGlow.opacity(0.20)
            )
        case .emerald:
            return (
                Color(red: 0.10, green: 0.60, blue: 0.42).opacity(0.25),
                BayanTokens.gold.opacity(0.16),
                Color(red: 0.02, green: 0.35, blue: 0.25).opacity(0.30)
            )
        case .midnight:
            return (
                BayanTokens.electricCyan.opacity(0.20),
                BayanTokens.gold.opacity(0.14),
                Color(red: 0.20, green: 0.30, blue: 0.85).opacity(0.22)
            )
        case .oled:
            return (
                Color.white.opacity(0.04),
                Color.white.opacity(0.02),
                Color.white.opacity(0.03)
            )
        case .sand:
            return (
                BayanTokens.gold.opacity(0.20),
                Color(red: 0.88, green: 0.78, blue: 0.62).opacity(0.30),
                Color(red: 0.94, green: 0.86, blue: 0.70).opacity(0.25)
            )
        }
    }

    // MARK: - Card Surfaces
    public var cardBackground: Color {
        switch self {
        case .obsidian: return Color.white.opacity(0.06)
        case .emerald: return Color(red: 0.04, green: 0.19, blue: 0.15).opacity(0.75)
        case .midnight: return Color(red: 0.07, green: 0.13, blue: 0.24).opacity(0.75)
        case .oled: return Color(red: 0.07, green: 0.07, blue: 0.07).opacity(0.90)
        case .sand: return Color(red: 0.99, green: 0.98, blue: 0.95).opacity(0.90)
        }
    }

    public var cardStroke: LinearGradient {
        switch self {
        case .obsidian:
            return BayanTokens.glassGoldStroke
        case .emerald:
            return BayanTokens.glassEmeraldStroke
        case .midnight:
            return LinearGradient(
                colors: [
                    BayanTokens.electricCyan.opacity(0.55),
                    BayanTokens.gold.opacity(0.20),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .oled:
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.25),
                    Color.white.opacity(0.08),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .sand:
            return LinearGradient(
                colors: [
                    BayanTokens.goldDark.opacity(0.40),
                    BayanTokens.goldDark.opacity(0.15),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Accent Colors & Gradients
    public var accentColor: Color {
        switch self {
        case .obsidian: return BayanTokens.gold
        case .emerald: return Color(red: 0.25, green: 0.90, blue: 0.60)
        case .midnight: return BayanTokens.electricCyan
        case .oled: return BayanTokens.goldSoft
        case .sand: return Color(red: 0.72, green: 0.52, blue: 0.20)
        }
    }

    public var secondaryAccentColor: Color {
        switch self {
        case .obsidian: return BayanTokens.goldSoft
        case .emerald: return BayanTokens.gold
        case .midnight: return BayanTokens.goldSoft
        case .oled: return Color(red: 0.85, green: 0.85, blue: 0.85)
        case .sand: return Color(red: 0.45, green: 0.32, blue: 0.15)
        }
    }

    // MARK: - Primary CTA Action Button
    public var ctaGradient: LinearGradient {
        switch self {
        case .obsidian:
            return LinearGradient(
                colors: [
                    BayanTokens.goldSoft,
                    BayanTokens.gold,
                    BayanTokens.goldDark
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .emerald:
            return LinearGradient(
                colors: [
                    Color(red: 0.30, green: 0.92, blue: 0.65),
                    Color(red: 0.15, green: 0.75, blue: 0.50),
                    BayanTokens.gold
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .midnight:
            return LinearGradient(
                colors: [
                    BayanTokens.electricCyan,
                    Color(red: 0.25, green: 0.60, blue: 0.98),
                    BayanTokens.goldSoft
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .oled:
            return LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.94, blue: 0.85),
                    Color(red: 0.85, green: 0.78, blue: 0.65)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .sand:
            return LinearGradient(
                colors: [
                    BayanTokens.gold,
                    Color(red: 0.78, green: 0.58, blue: 0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    public var ctaTextColor: Color {
        switch self {
        case .sand: return .white
        default: return Color(red: 0.06, green: 0.07, blue: 0.09)
        }
    }

    // MARK: - Typography Colors
    public var textPrimary: Color {
        switch self {
        case .sand: return Color(red: 0.12, green: 0.09, blue: 0.05)
        default: return .white
        }
    }

    public var textSecondary: Color {
        switch self {
        case .sand: return Color(red: 0.45, green: 0.38, blue: 0.30)
        case .obsidian: return Color.white.opacity(0.70)
        case .emerald: return Color(red: 0.75, green: 0.90, blue: 0.82)
        case .midnight: return Color(red: 0.70, green: 0.82, blue: 0.95)
        case .oled: return Color.white.opacity(0.68)
        }
    }
}

// MARK: - Centralized App Theme Manager
public final class AppThemeManager: ObservableObject {
    public static let shared = AppThemeManager()

    @Published public var currentTheme: StoryAppTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "storyteller_app_theme")
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "storyteller_app_theme") ?? StoryAppTheme.obsidian.rawValue
        self.currentTheme = StoryAppTheme(rawValue: saved) ?? .obsidian
    }

    public func setTheme(_ theme: StoryAppTheme) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.currentTheme = theme
        }
    }
}
