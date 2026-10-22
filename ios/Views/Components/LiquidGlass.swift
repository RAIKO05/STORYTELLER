import SwiftUI

// MARK: - Liquid Mesh Ambient Background
public struct LiquidMeshBackground: View {
    @State private var animateBlobs: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            // Base obsidian black canvas
            Color(red: 0.04, green: 0.05, blue: 0.08)
                .ignoresSafeArea()

            // Fluid Glowing Mesh Orbs
            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height

                // Top-Left Cyan Ambient Glow
                Circle()
                    .fill(Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.18))
                    .frame(width: w * 0.85, height: w * 0.85)
                    .blur(radius: 90)
                    .offset(
                        x: animateBlobs ? -w * 0.15 : -w * 0.35,
                        y: animateBlobs ? -h * 0.08 : -h * 0.15
                    )

                // Middle-Right Magenta / Violet Glow
                Circle()
                    .fill(Color(red: 0.85, green: 0.1, blue: 0.6).opacity(0.16))
                    .frame(width: w * 0.9, height: w * 0.9)
                    .blur(radius: 110)
                    .offset(
                        x: animateBlobs ? w * 0.45 : w * 0.25,
                        y: animateBlobs ? h * 0.25 : h * 0.40
                    )

                // Bottom-Left Deep Royal Indigo Glow
                Circle()
                    .fill(Color(red: 0.3, green: 0.15, blue: 0.9).opacity(0.20))
                    .frame(width: w * 0.95, height: w * 0.95)
                    .blur(radius: 120)
                    .offset(
                        x: animateBlobs ? -w * 0.25 : -w * 0.05,
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

// MARK: - Liquid Glass Card Modifier
public struct LiquidGlassCardModifier: ViewModifier {
    public var cornerRadius: CGFloat = 22
    public var strokeColor: Color = Color.white
    public var opacity: Double = 0.55

    public func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Ultra thin frosted glass material
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.85)

                    // Translucent obsidian dark tint layer
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.11, green: 0.13, blue: 0.20).opacity(0.75),
                                    Color(red: 0.07, green: 0.08, blue: 0.14).opacity(0.65)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Specular light sheen highlight on upper edge
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.32),
                                    Color.cyan.opacity(0.18),
                                    Color.purple.opacity(0.08),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 8)
            .shadow(color: Color.cyan.opacity(0.04), radius: 24, x: 0, y: 2)
    }
}

public extension View {
    func liquidGlassCard(cornerRadius: CGFloat = 22) -> some View {
        self.modifier(LiquidGlassCardModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Liquid Glass Button Style
public struct LiquidGlassButtonStyle: ButtonStyle {
    public var isPrimary: Bool = false

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { pressed in
                if pressed {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
    }
}

// MARK: - Liquid Glass Pill Badge
public struct LiquidGlassPill: View {
    public let text: String
    public var icon: String? = nil
    public var tintColor: Color = .cyan

    public init(text: String, icon: String? = nil, tintColor: Color = .cyan) {
        self.text = text
        self.icon = icon
        self.tintColor = tintColor
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
        .foregroundColor(tintColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tintColor.opacity(0.12))
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(tintColor.opacity(0.30), lineWidth: 1)
            }
        )
    }
}

// MARK: - Glowing Liquid CTA Button
public struct GlowingLiquidCTA: View {
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
                // Outer Liquid Ambient Glow
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.0, green: 0.95, blue: 1.0),
                                Color(red: 0.25, green: 0.45, blue: 1.0),
                                Color(red: 0.95, green: 0.15, blue: 0.65)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .blur(radius: 12)
                    .opacity(isLoading ? 0.3 : 0.65)

                // Glass Surface
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.0, green: 0.92, blue: 1.0),
                                Color(red: 0.35, green: 0.55, blue: 1.0),
                                Color(red: 0.92, green: 0.20, blue: 0.60)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        // Gloss specular sheen on top edge
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.55),
                                        Color.white.opacity(0.15)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.2
                            )
                    )

                // Button Content
                HStack(spacing: 10) {
                    if isLoading {
                        ProgressView()
                            .tint(.black)
                        Text(progressText.isEmpty ? "RENDERING..." : progressText.uppercased())
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundColor(.black)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(.black)
                        VStack(spacing: 2) {
                            Text(title)
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundColor(.black)
                                .tracking(0.5)

                            if let sub = subtitle {
                                Text(sub)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.black.opacity(0.75))
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
