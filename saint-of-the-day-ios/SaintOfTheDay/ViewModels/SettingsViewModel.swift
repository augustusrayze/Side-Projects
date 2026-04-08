import Foundation
import UserNotifications
import Observation

@Observable
final class SettingsViewModel {
    var notificationsEnabled: Bool = false

    func checkNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsEnabled = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
    }

    func requestNotificationPermission() async {
        let granted = await NotificationService.shared.requestPermissionIfNeeded()
        if granted {
            await NotificationService.shared.scheduleDailyNotification()
        }
        await checkNotificationStatus()
    }

    func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            Task { @MainActor in
                await UIApplication.shared.open(url)
            }
        }
    }
}
