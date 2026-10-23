import SwiftUI

public struct StoryCardView: View {
    @ObservedObject private var themeManager = AppThemeManager.shared
    public let story: Story
    public let isSelected: Bool
    public let onSelect: () -> Void

    public init(story: Story, isSelected: Bool = false, onSelect: @escaping () -> Void) {
        self.story = story
        self.isSelected = isSelected
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: {
            onSelect()
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
        }) {
            VStack(alignment: .leading, spacing: 8) {
                Text(story.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.currentTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(story.story)
                    .font(.system(size: 11))
                    .foregroundColor(themeManager.currentTheme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    if let sub = story.subreddit {
                        Text(sub.hasPrefix("r/") ? sub : "r/\(sub)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(themeManager.currentTheme.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(themeManager.currentTheme.accentColor.opacity(0.12))
                            .cornerRadius(6)
                    } else if let topic = story.topic {
                        Text(topic)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(BayanTokens.gold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(BayanTokens.gold.opacity(0.12))
                            .cornerRadius(6)
                    }

                    if let up = story.upvotes {
                        Text("🔥 \(up)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(themeManager.currentTheme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right.circle")
                        .font(.system(size: 13))
                        .foregroundColor(isSelected ? themeManager.currentTheme.accentColor : themeManager.currentTheme.textSecondary.opacity(0.5))
                }
            }
            .padding(12)
            .frame(width: 240, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isSelected ? themeManager.currentTheme.accentColor.opacity(0.15) : themeManager.currentTheme.cardBackground)

                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            isSelected ?
                                (themeManager.currentTheme.isDark ? BayanTokens.glassGoldStroke : themeManager.currentTheme.cardStroke) :
                                LinearGradient(colors: [Color.white.opacity(0.15), Color.white.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: isSelected ? 1.8 : 1.0
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: isSelected ? themeManager.currentTheme.accentColor.opacity(0.25) : Color.black.opacity(0.20), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}
