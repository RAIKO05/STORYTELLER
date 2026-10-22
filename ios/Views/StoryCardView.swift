import SwiftUI

public struct StoryCardView: View {
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
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                Text(story.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(story.story)
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.65))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    if let sub = story.subreddit {
                        Text(sub.hasPrefix("r/") ? sub : "r/\(sub)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.cyan.opacity(0.12))
                            .cornerRadius(6)
                    } else if let topic = story.topic {
                        Text(topic)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.purple)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.12))
                            .cornerRadius(6)
                    }

                    if let up = story.upvotes {
                        Text("🔥 \(up)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right.circle")
                        .font(.system(size: 13))
                        .foregroundColor(isSelected ? .cyan : .gray.opacity(0.5))
                }
            }
            .padding(12)
            .frame(width: 240, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.7)

                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isSelected ? Color.cyan.opacity(0.14) : Color(red: 0.10, green: 0.12, blue: 0.18).opacity(0.75))

                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            isSelected ?
                                LinearGradient(colors: [Color.cyan, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                LinearGradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: isSelected ? 1.6 : 1.0
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: isSelected ? Color.cyan.opacity(0.2) : Color.black.opacity(0.25), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}
