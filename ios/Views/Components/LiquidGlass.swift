import SwiftUI

// MARK: - Dynamic Theme-Adaptive Liquid Mesh Ambient Background
public struct LiquidMeshBackground: View {
    @ObservedObject private var themeManager = AppThemeManager.shared
    @State private var animateBlobs: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            // Base Theme Canvas Background
            themeManager.currentTheme.backgroundColor
                .ignoresSafeArea()

            themeManager.currentTheme.backgroundGradient
                .ignoresSafeArea()

            // Fluid Glowing Mesh Orbs (Adapts to Active Theme)
            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height
                let mesh = themeManager.currentTheme.meshColors

                // Top-Left Ambient Orb
                Circle()
                    .fill(mesh.0)
                    .frame(width: w * 0.90, height: w * 0.90)
                    .blur(radius: 95)
                    .offset(
                        x: animateBlobs ? -w * 0.15 : -w * 0.35,
                        y: animateBlobs ? -h * 0.08 : -h * 0.15
                    )

                // Middle-Right Ambient Orb
                Circle()
                    .fill(mesh.1)
                    .frame(width: w * 0.95, height: w * 0.95)
                    .blur(radius: 110)
                    .offset(
                        x: animateBlobs ? w * 0.40 : w * 0.20,
                        y: animateBlobs ? h * 0.20 : h * 0.38
                    )

                // Bottom-Left Ambient Orb
                Circle()
                    .fill(mesh.2)
                    .frame(width: w * 1.0, height: w * 1.0)
                    .blur(radius: 125)
                    .offset(
                        x: animateBlobs ? -w * 0.20 : -w * 0.05,
                        y: animateBlobs ? h * 0.65 : h * 0.50
                    )
            }
            .ignoresSafeArea()
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 8.0)
                    .repeatForever(autoreverses: true)
                ) {
                    animateBlobs.toggle()
                }
            }
        }
    }
}

// MARK: - Bayan Liquid Glass Card Modifier
public struct LiquidGlassCardModifier: ViewModifier {
    @ObservedObject private var themeManager = AppThemeManager.shared
    public var cornerRadius: CGFloat = 22
    public var isGoldBorder: Bool = false

    public func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Ultra-thin frosted glass
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    // Theme card background tint
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(themeManager.currentTheme.cardBackground)

                    // Specular rim stroke
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            isGoldBorder ? BayanTokens.glassGoldStroke : themeManager.currentTheme.cardStroke,
                            lineWidth: 1.2
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.32), radius: 16, x: 0, y: 8)
            .shadow(color: themeManager.currentTheme.accentColor.opacity(0.06), radius: 24, x: 0, y: 2)
    }
}

public extension View {
    func liquidGlassCard(cornerRadius: CGFloat = 22, isGoldBorder: Bool = false) -> some View {
        self.modifier(LiquidGlassCardModifier(cornerRadius: cornerRadius, isGoldBorder: isGoldBorder))
    }

    func liquidGlass(cornerRadius: CGFloat = 22, isGoldBorder: Bool = false) -> some View {
        self.modifier(LiquidGlassCardModifier(cornerRadius: cornerRadius, isGoldBorder: isGoldBorder))
    }
}

// MARK: - Liquid Glass Button Style with Haptics
public struct LiquidGlassButtonStyle: ButtonStyle {
    public var isPrimary: Bool = false

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { pressed in
                if pressed {
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    #endif
                }
            }
    }
}

// MARK: - Liquid Glass Pill Badge
public struct LiquidGlassPill: View {
    @ObservedObject private var themeManager = AppThemeManager.shared
    public let text: String
    public var icon: String? = nil
    public var tintColor: Color? = nil
    public var isGold: Bool = false

    public init(text: String, icon: String? = nil, tintColor: Color? = nil, isGold: Bool = false) {
        self.text = text
        self.icon = icon
        self.tintColor = tintColor
        self.isGold = isGold
    }

    private var activeColor: Color {
        if isGold { return BayanTokens.gold }
        return tintColor ?? themeManager.currentTheme.accentColor
    }

    public var body: some View {
        HStack(spacing: 5) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
            }
            Text(text)
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundColor(activeColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(activeColor.opacity(0.12))
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isGold ? BayanTokens.glassGoldStroke : LinearGradient(
                            colors: [activeColor.opacity(0.5), activeColor.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
    }
}

// MARK: - Glowing Liquid CTA Button (Bayan Shimmering Gold / Emerald Luxury Button)
public struct GlowingLiquidCTA: View {
    @ObservedObject private var themeManager = AppThemeManager.shared
    public let title: String
    public var subtitle: String? = nil
    public var icon: String = "bolt.fill"
    public var isLoading: Bool = false
    public var progressText: String = ""
    public var action: () -> Void

    public init(
        title: String,
        subtitle: String? = nil,
        icon: String = "bolt.fill",
        isLoading: Bool = false,
        progressText: String = "",
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.isLoading = isLoading
        self.progressText = progressText
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                // Outer Ambient Glow
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(themeManager.currentTheme.ctaGradient)
                    .blur(radius: 14)
                    .opacity(isLoading ? 0.35 : 0.65)

                // Surface with Theme CTA Gradient
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(themeManager.currentTheme.ctaGradient)
                    .overlay(
                        // Specular Light Sheen Rim
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.65),
                                        Color.white.opacity(0.15)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.2
                            )
                    )

                // Content
                HStack(spacing: 10) {
                    if isLoading {
                        ProgressView()
                            .tint(themeManager.currentTheme.ctaTextColor)
                        Text(progressText.isEmpty ? "RENDERING..." : progressText.uppercased())
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundColor(themeManager.currentTheme.ctaTextColor)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(themeManager.currentTheme.ctaTextColor)

                        VStack(spacing: 2) {
                            Text(title)
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundColor(themeManager.currentTheme.ctaTextColor)
                                .tracking(0.5)

                            if let sub = subtitle {
                                Text(sub)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(themeManager.currentTheme.ctaTextColor.opacity(0.80))
                            }
                        }
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
            }
        }
        .buttonStyle(LiquidGlassButtonStyle())
    }
}
