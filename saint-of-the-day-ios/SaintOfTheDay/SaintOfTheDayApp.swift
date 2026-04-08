import SwiftUI

@main
struct SaintOfTheDayApp: App {
    @AppStorage("appColorScheme") private var storedScheme: String = "system"

    init() {
        URLCache.shared = URLCache(
            memoryCapacity: 20 * 1024 * 1024,
            diskCapacity: 100 * 1024 * 1024,
            directory: nil
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(resolvedColorScheme)
                .task {
                    await NotificationService.shared.rescheduleIfNeeded()
                }
        }
    }

    private var resolvedColorScheme: ColorScheme? {
        switch storedScheme {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil  // "system" — follow iOS setting
        }
    }
}
