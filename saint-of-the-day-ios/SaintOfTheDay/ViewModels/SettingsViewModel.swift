import Foundation
import Observation
import UIKit
import UserNotifications

@Observable
final class SettingsViewModel {
    var notificationsEnabled: Bool = false

    // Stored as separate ints so @Observable tracks changes correctly.
    // Backed by UserDefaults; default is 8:00 AM.
    var notificationHour:   Int = UserDefaults.standard.object(forKey: "notificationHour")   as? Int ?? 8
    var notificationMinute: Int = UserDefaults.standard.object(forKey: "notificationMinute") as? Int ?? 0

    /// A Date whose hour/minute reflects the stored preference (day is today — only time matters).
    var notificationTime: Date {
        get {
            Calendar.current.date(
                bySettingHour: notificationHour,
                minute: notificationMinute,
                second: 0,
                of: Date()
            ) ?? Date()
        }
        set {
            let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            notificationHour   = c.hour   ?? 8
            notificationMinute = c.minute ?? 0
            UserDefaults.standard.set(notificationHour,   forKey: "notificationHour")
            UserDefaults.standard.set(notificationMinute, forKey: "notificationMinute")
        }
    }

    func checkNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsEnabled = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
    }

    func requestNotificationPermission() async {
        let granted = await NotificationService.shared.requestPermissionIfNeeded()
        if granted {
            await NotificationService.shared.scheduleDailyNotification(
                imageURL: nil,
                saintName: nil,
                date: Date()
            )
        }
        await checkNotificationStatus()
    }

    /// Persists the new time and immediately reschedules the notification.
    func updateNotificationTime(_ date: Date) async {
        notificationTime = date          // updates stored ints + UserDefaults
        await NotificationService.shared.rescheduleNotification()
    }

    func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            Task { @MainActor in
                await UIApplication.shared.open(url)
            }
        }
    }
}
