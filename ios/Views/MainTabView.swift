import SwiftUI

public struct MainTabView: View {
    @ObservedObject var api = StoryTellerAPIService.shared
    @State private var selectedTab: Int = 0

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            // Background View for the selected tab
            Group {
                switch selectedTab {
                case 0:
                    CreatorView()
                case 1:
                    GalleryView()
                case 2:
                    ServerConnectSheet()
                default:
                    CreatorView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floating Liquid Glass Navigation Bar
            floatingLiquidTabBar
        }
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - Floating Liquid Tab Bar
    private var floatingLiquidTabBar: some View {
        HStack(spacing: 0) {
            tabButton(index: 0, title: "Studio", icon: "wand.and.stars")
            tabButton(index: 1, title: "Gallery", icon: "play.rectangle.on.rectangle.fill")
            tabButton(index: 2, title: "Connect", icon: "wifi")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            ZStack {
                // Frosted ultra-thin glass
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.92)

                Capsule(style: .continuous)
                    .fill(Color(red: 0.08, green: 0.10, blue: 0.16).opacity(0.80))

                // Iridescent specular glass rim
                Capsule(style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.35),
                                Color.cyan.opacity(0.25),
                                Color.purple.opacity(0.12),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            }
        )
        .clipShape(Capsule(style: .continuous))
        .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 10)
        .shadow(color: Color.cyan.opacity(0.12), radius: 30, x: 0, y: 4)
        .padding(.horizontal, 36)
        .padding(.bottom, 12)
    }

    private func tabButton(index: Int, title: String, icon: String) -> some View {
        let isSelected = selectedTab == index

        return Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                selectedTab = index
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color.cyan.opacity(0.18))
                            .frame(width: 36, height: 36)
                            .blur(radius: 4)
                    }

                    Image(systemName: icon)
                        .font(.system(size: isSelected ? 18 : 16, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? Color.cyan : Color.gray.opacity(0.85))
                }

                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? Color.white : Color.gray.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
