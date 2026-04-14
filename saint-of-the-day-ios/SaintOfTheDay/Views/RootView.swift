import SwiftUI

struct RootView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var router = AppRouter.shared

    var body: some View {
        TabView(selection: $router.selectedTab) {
            TodayView()
                .tag(RootTab.saints)
                .tabItem {
                    Label("Saints", systemImage: "person.3.fill")
                }

            PrayerView()
                .tag(RootTab.prayer)
                .tabItem {
                    Label("Prayer", systemImage: "book.closed.fill")
                }

            SavedView()
                .tag(RootTab.saved)
                .tabItem {
                    Label("Saved", systemImage: "bookmark")
                }
        }
        .tint(Color.ancientGold)
        .fullScreenCover(isPresented: .constant(!hasSeenOnboarding)) {
            OnboardingView()
        }
    }
}
