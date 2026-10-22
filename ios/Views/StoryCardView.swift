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
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                Text(story.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(story.story)
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.7, green: 0.75, blue: 0.85))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 12) {
                    if let sub = story.subreddit {
                        Text("r/\(sub)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.cyan)
                    } else if let topic = story.topic {
                        Text(topic)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.purple)
                    }

                    if let up = story.upvotes {
                        Text("👍 \(up)")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }

                    Spacer()
                }
            }
            .padding(12)
            .background(isSelected ? Color.cyan.opacity(0.15) : Color(red: 0.09, green: 0.12, blue: 0.18))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.cyan : Color(red: 0.16, green: 0.20, blue: 0.30), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
