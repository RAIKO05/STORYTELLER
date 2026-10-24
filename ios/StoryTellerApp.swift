import SwiftUI

@main
struct StoryTellerApp: App {
    @ObservedObject private var themeManager = AppThemeManager.shared

    init() {
        // Enforce Automated Security Shield & Anti-Piracy Environment Verification
        AppSecurityShield.shared.validateEnvironmentIntegrity()

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithTransparentBackground()
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(themeManager.currentTheme.isDark ? .dark : .light)
        }
    }
}
