import SwiftUI

// MARK: - App Theme Selector Card (Bayan-Style Multi-Theme Switcher)
public struct AppThemeSelectorCard: View {
    @ObservedObject private var themeManager = AppThemeManager.shared
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Theme & Atmosphere")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.currentTheme.textPrimary)

                    Text("Liquid Glass Color System")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme.accentColor)
                }

                Spacer()

                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(themeManager.currentTheme.accentColor)
            }
            .padding(.horizontal, 4)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(StoryAppTheme.allCases) { theme in
                    let isSelected = themeManager.currentTheme == theme

                    Button {
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                        themeManager.setTheme(theme)
                    } label: {
                        VStack(spacing: 8) {
                            // Mini Preview Box
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(theme.backgroundGradient)

                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(theme.accentColor)
                                        .frame(width: 8, height: 8)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(theme.previewTextColor.opacity(0.8))
                                        .frame(width: 32, height: 6)
                                }
                            }
                            .frame(height: 38)
                            .padding(.horizontal, 6)
                            .padding(.top, 6)

                            // Title & Description
                            VStack(spacing: 2) {
                                Text(theme.title)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(theme.previewTextColor)

                                Text(theme.subtitle)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(theme.previewTextColor.opacity(0.65))
                                    .lineLimit(1)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 4)
                            .padding(.bottom, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .background(theme.previewBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    isSelected
                                        ? (theme.isDark ? BayanTokens.gold : Color(red: 0.72, green: 0.52, blue: 0.20))
                                        : Color.white.opacity(0.10),
                                    lineWidth: isSelected ? 2.2 : 1.0
                                )
                        )
                        .shadow(
                            color: isSelected ? BayanTokens.gold.opacity(0.35) : Color.black.opacity(0.15),
                            radius: isSelected ? 8 : 4,
                            y: 3
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(themeManager.currentTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(themeManager.currentTheme.cardStroke, lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.30), radius: 16, x: 0, y: 8)
    }
}

// MARK: - Dedicated Theme Picker Modal Sheet
public struct ThemePickerSheet: View {
    @ObservedObject private var themeManager = AppThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                themeManager.currentTheme.backgroundColor.ignoresSafeArea()
                themeManager.currentTheme.backgroundGradient.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        AppThemeSelectorCard()

                        // Information Card
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .foregroundColor(themeManager.currentTheme.accentColor)
                                Text("Aesthetic Inspiration")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(themeManager.currentTheme.textPrimary)
                            }

                            Text("Inspired by the Bayan Luxury Quran design system: deep obsidian depths, imperial emerald velvets, royal gold accents (#E6BD61), and dynamic liquid glass specular reflections.")
                                .font(.system(size: 11))
                                .foregroundColor(themeManager.currentTheme.textSecondary)
                                .lineSpacing(3)
                        }
                        .padding(16)
                        .background(themeManager.currentTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(themeManager.currentTheme.cardStroke, lineWidth: 1)
                        )
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Appearance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.accentColor)
                    .font(.body.weight(.bold))
                }
            }
        }
    }
}
