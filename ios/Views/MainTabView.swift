import SwiftUI

public struct MainTabView: View {
    @ObservedObject var api = StoryTellerAPIService.shared
    @State private var selectedTab: Int = 0

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            CreatorView()
                .tabItem {
                    Label("Studio", systemImage: "wand.and.stars")
                }
                .tag(0)

            NavigationStack {
                ZStack {
                    Color(red: 0.05, green: 0.06, blue: 0.09).ignoresSafeArea()
                    StoryTellerWebView(urlString: api.baseURL)
                }
                .navigationTitle("Web Studio")
                .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Web Studio", systemImage: "globe")
            }
            .tag(1)

            GalleryView()
                .tabItem {
                    Label("Gallery", systemImage: "play.rectangle.on.rectangle.fill")
                }
                .tag(2)

            ServerConnectSheet()
                .tabItem {
                    Label("Connect", systemImage: "wifi")
                }
                .tag(3)
        }
        .tint(.cyan)
    }
}
