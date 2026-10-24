// ios/Views/Components/LiquidGlass.swift
import SwiftUI

// ==============================================================================
// CORE DOMAIN 2: THE "LIQUID GLASS" FUTURE UI KIT
// 1. Reactive Fluid Material (FluidGlassView with Canvas touch ripple physics)
// 2. Gelatinous Interaction Control (LiquidButton with surface tension morphing)
// 3. Viscous Container Snap (LiquidContainer with elastic droplet interpolation)
// ==============================================================================

// MARK: - 1. REACTIVE FLUID MATERIAL (FluidGlassView)

public struct FluidRipple: Identifiable {
    public let id = UUID()
    public var origin: CGPoint
    public var startTime: TimeInterval
    public var maxRadius: CGFloat
    public var intensity: CGFloat
}

/// Native Canvas-based fluid glass surface renderer with dynamic refraction,
/// organic harmonic wave oscillation, and touch-responsive ripple physics.
public struct FluidGlassView: View {
    @ObservedObject private var themeManager = AppThemeManager.shared
    @State private var ripples: [FluidRipple] = []
    @State private var touchLocation: CGPoint? = nil

    public init() {}

    public var body: some View {
        TimelineView(.animation) { timeline in
            let currentTime = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                let w = size.width
                let h = size.height
                let baseColors = themeManager.currentTheme.meshColors

                // A. Base Ambient Fluid Field
                let bgGradient = Gradient(colors: [
                    themeManager.currentTheme.backgroundColor,
                    themeManager.currentTheme.backgroundColor.opacity(0.85)
                ])
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(bgGradient, startPoint: .zero, endPoint: CGPoint(x: w, y: h))
                )

                // B. Harmonic Organic Wave Oscillations
                let phase1 = sin(currentTime * 0.75)
                let phase2 = cos(currentTime * 0.60)
                let phase3 = sin(currentTime * 0.45)

                let p1 = CGPoint(x: w * (0.25 + 0.12 * phase1), y: h * (0.20 + 0.08 * phase2))
                let p2 = CGPoint(x: w * (0.80 - 0.10 * phase2), y: h * (0.45 + 0.10 * phase3))
                let p3 = CGPoint(x: w * (0.35 + 0.15 * phase3), y: h * (0.80 - 0.09 * phase1))

                // Draw organic refractive liquid orbs
                drawFluidOrb(context: context, center: p1, radius: w * 0.55, color: baseColors.0, alpha: 0.35)
                drawFluidOrb(context: context, center: p2, radius: w * 0.60, color: baseColors.1, alpha: 0.28)
                drawFluidOrb(context: context, center: p3, radius: w * 0.65, color: baseColors.2, alpha: 0.32)

                // C. Dynamic Touch Ripple Propagation & Refraction Highlights
                for ripple in ripples {
                    let elapsed = currentTime - ripple.startTime
                    if elapsed < 2.2 {
                        let progress = elapsed / 2.2
                        let currentRadius = ripple.maxRadius * CGFloat(progress)
                        let alpha = (1.0 - progress) * ripple.intensity

                        var ripplePath = Path()
                        ripplePath.addEllipse(in: CGRect(
                            x: ripple.origin.x - currentRadius,
                            y: ripple.origin.y - currentRadius,
                            width: currentRadius * 2,
                            height: currentRadius * 2
                        ))

                        // High-distortion refraction caustic stroke
                        context.stroke(
                            ripplePath,
                            with: .color(Color.white.opacity(Double(alpha * 0.45))),
                            lineWidth: max(1.0, 3.5 * (1.0 - progress))
                        )

                        // Golden specular dispersion ring
                        context.stroke(
                            ripplePath,
                            with: .color(BayanTokens.gold.opacity(Double(alpha * 0.30))),
                            lineWidth: max(0.5, 2.0 * (1.0 - progress))
                        )
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let now = Date().timeIntervalSinceReferenceDate
                        // Spawn physical ripple with damping
                        if ripples.count < 8 {
                            ripples.append(FluidRipple(
                                origin: value.location,
                                startTime: now,
                                maxRadius: 180,
                                intensity: 0.75
                            ))
                            #if os(iOS)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.4)
                            #endif
                        }
                    }
            )
            .overlay(
                // High-distortion frosted glass optical layer
                Rectangle()
                    .fill(.ultraThinMaterial.opacity(0.82))
                    .ignoresSafeArea()
            )
            .ignoresSafeArea()
            .onChange(of: timeline.date) { _ in
                // Clean up expired ripples
                let now = Date().timeIntervalSinceReferenceDate
                ripples.removeAll { now - $0.startTime >= 2.2 }
            }
        }
    }

    private func drawFluidOrb(context: GraphicsContext, center: CGPoint, radius: CGFloat, color: Color, alpha: Double) {
        let bounds = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        var path = Path()
        path.addEllipse(in: bounds)
        let grad = Gradient(colors: [
            color.opacity(alpha),
            color.opacity(alpha * 0.4),
            Color.clear
        ])
        context.fill(path, with: .radialGradient(grad, center: center, startRadius: 0, endRadius: radius))
    }
}

// MARK: - 2. GELATINOUS INTERACTION CONTROL (LiquidButton)

public struct GelatinousBlobShape: Shape {
    public var stretchX: CGFloat
    public var stretchY: CGFloat
    public var cornerRadius: CGFloat

    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(stretchX, stretchY) }
        set {
            stretchX = newValue.first
            stretchY = newValue.second
        }
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width + stretchX
        let h = rect.height + stretchY
        let x = rect.midX - w / 2
        let y = rect.midY - h / 2

        path.addRoundedRect(
            in: CGRect(x: x, y: y, width: w, height: h),
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius),
            style: .continuous
        )
        return path
    }
}

/// Primary action button simulating physical liquid surface tension.
/// Warps, stretches along the drag vector, and fluidly bounces on release with multi-tier haptics.
public struct LiquidButton: View {
    @ObservedObject private var themeManager = AppThemeManager.shared
    public let title: String
    public var icon: String = "bolt.fill"
    public var isLoading: Bool = false
    public var progressText: String = ""
    public var action: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isPressed: Bool = false

    public init(
        title: String,
        icon: String = "bolt.fill",
        isLoading: Bool = false,
        progressText: String = "",
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.progressText = progressText
        self.action = action
    }

    public var body: some View {
        ZStack {
            // Ambient Liquid Shadow with Refractive Glow
            GelatinousBlobShape(
                stretchX: dragOffset.width * 0.45,
                stretchY: dragOffset.height * 0.45,
                cornerRadius: 24
            )
            .fill(themeManager.currentTheme.ctaGradient)
            .blur(radius: isPressed ? 18 : 12)
            .opacity(isPressed ? 0.85 : 0.55)

            // Viscous Liquid Body
            GelatinousBlobShape(
                stretchX: dragOffset.width * 0.35,
                stretchY: dragOffset.height * 0.35,
                cornerRadius: 24
            )
            .fill(themeManager.currentTheme.ctaGradient)
            .overlay(
                // Liquid Specular Sheen Stroke
                GelatinousBlobShape(
                    stretchX: dragOffset.width * 0.35,
                    stretchY: dragOffset.height * 0.35,
                    cornerRadius: 24
                )
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.85),
                            BayanTokens.gold.opacity(0.40),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.4
                )
            )

            // Button Contents
            HStack(spacing: 9) {
                if isLoading {
                    ProgressView()
                        .tint(themeManager.currentTheme.ctaTextColor)
                    Text(progressText.isEmpty ? "PROCESSING..." : progressText.uppercased())
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(themeManager.currentTheme.ctaTextColor)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(themeManager.currentTheme.ctaTextColor)
                    Text(title)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundColor(themeManager.currentTheme.ctaTextColor)
                        .tracking(0.6)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
        }
        .scaleEffect(isPressed ? 0.94 : 1.0)
        .offset(dragOffset)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { gesture in
                    if !isPressed {
                        isPressed = true
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.8)
                        #endif
                    }
                    // Physical surface tension resistance (asymptotic damping)
                    let maxStretch: CGFloat = 32.0
                    let tx = gesture.translation.width
                    let ty = gesture.translation.height
                    let dampedX = (tx / (1.0 + abs(tx) / maxStretch))
                    let dampedY = (ty / (1.0 + abs(ty) / maxStretch))

                    withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.55)) {
                        dragOffset = CGSize(width: dampedX, height: dampedY)
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.9)
                    #endif

                    // Elastic surface tension snap back
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.52, blendDuration: 0)) {
                        dragOffset = .zero
                    }
                    if !isLoading {
                        action()
                    }
                }
        )
    }
}

// MARK: - 3. VISCOUS CONTAINER SNAP (LiquidContainer)

/// Container layout where selection bubbles stretch, warp, and snap like viscous liquid droplets.
public struct LiquidContainer<Item: Identifiable & Equatable, Content: View>: View {
    @ObservedObject private var themeManager = AppThemeManager.shared
    public let items: [Item]
    @Binding public var selectedItem: Item
    public let content: (Item, Bool) -> Content

    @Namespace private var containerNamespace

    public init(
        items: [Item],
        selectedItem: Binding<Item>,
        @ViewBuilder content: @escaping (Item, Bool) -> Content
    ) {
        self.items = items
        self._selectedItem = selectedItem
        self.content = content
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(items) { item in
                let isSelected = item == selectedItem

                Button {
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
                    #endif
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.68)) {
                        selectedItem = item
                    }
                } label: {
                    content(item, isSelected)
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
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [
                                                        themeManager.currentTheme.accentColor.opacity(0.7),
                                                        BayanTokens.gold.opacity(0.4),
                                                        Color.clear
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1.2
                                            )
                                    )
                                    .shadow(color: themeManager.currentTheme.accentColor.opacity(0.25), radius: 8, x: 0, y: 2)
                                    .matchedGeometryEffect(id: "viscousSnapCapsule", in: containerNamespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(
            ZStack {
                Capsule()
                    .fill(.ultraThinMaterial)
                Capsule()
                    .fill(themeManager.currentTheme.cardBackground.opacity(0.85))
                Capsule()
                    .strokeBorder(themeManager.currentTheme.cardStroke, lineWidth: 1.0)
            }
        )
        .clipShape(Capsule())
    }
}

// MARK: - PRESERVED & ENHANCED BAYAN LUXURY SYSTEM COMPATIBILITY

public struct LiquidMeshBackground: View {
    public init() {}
    public var body: some View {
        FluidGlassView()
    }
}

public struct LiquidGlassCardModifier: ViewModifier {
    @ObservedObject private var themeManager = AppThemeManager.shared
    public var cornerRadius: CGFloat = 22
    public var isGoldBorder: Bool = false

    public func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(themeManager.currentTheme.cardBackground)
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

public struct LiquidGlassButtonStyle: ButtonStyle {
    public var isPrimary: Bool = false

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { pressed in
                if pressed {
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    #endif
                }
            }
    }
}

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
        LiquidButton(
            title: title,
            icon: icon,
            isLoading: isLoading,
            progressText: progressText,
            action: action
        )
    }
}
