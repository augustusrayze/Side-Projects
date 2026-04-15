import Foundation
import UserNotifications

@MainActor
final class NotificationService: NSObject {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()
    private let notificationID = "daily-saint-8am"

    private override init() {}

    func configure() {
        center.delegate = self
    }

    func requestPermissionIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    func rescheduleIfNeeded() async {
        guard await isPermissionGranted() else { return }
        guard !(await isAlreadyScheduled()) else { return }
        await scheduleDailyNotification(imageURL: nil, saintName: nil, date: Date())
    }

    func scheduleDailyNotification(imageURL: URL?, saintName: String?, date: Date) async {
        let content = UNMutableNotificationContent()
        content.title = "Saint of the Day"
        if let saintName, !saintName.isEmpty {
            content.body = "Open the app to meet \(saintName)."
        } else {
            content.body = "Open the app to meet today's featured saint."
        }
        content.sound = .default
        content.badge = 1
        content.userInfo["targetTab"] = "saints"
        content.userInfo["saintDate"] = notificationDateString(from: date)

        // Attach saint image if available
        if let imageURL {
            content.attachments = (try? await makeAttachment(from: imageURL)).map { [$0] } ?? []
        }

        var components = DateComponents()
        components.hour   = UserDefaults.standard.object(forKey: "notificationHour")   as? Int ?? 8
        components.minute = UserDefaults.standard.object(forKey: "notificationMinute") as? Int ?? 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)
        try? await center.add(request)
    }

    /// Cancels the existing daily notification and reschedules it with the
    /// currently stored hour/minute preference (no image update needed here).
    func rescheduleNotification() async {
        guard await isPermissionGranted() else { return }
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
        await scheduleDailyNotification(imageURL: nil, saintName: nil, date: Date())
    }

    /// Called after today's saint loads — cancels existing notification and reschedules with image.
    func updateNotificationImage(from imageURL: URL, saintName: String, date: Date) async {
        guard await isPermissionGranted() else { return }
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
        await scheduleDailyNotification(imageURL: imageURL, saintName: saintName, date: date)
    }

    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
    }

    // MARK: - Private

    private func makeAttachment(from url: URL) async throws -> UNNotificationAttachment {
        let (data, _) = try await URLSession.shared.data(from: url)
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("saint-notif-image.jpg")
        try data.write(to: tmpURL, options: .atomic)
        return try UNNotificationAttachment(identifier: "saint-image", url: tmpURL, options: nil)
    }

    private func isPermissionGranted() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    private func isAlreadyScheduled() async -> Bool {
        let pending = await center.pendingNotificationRequests()
        return pending.contains { $0.identifier == notificationID }
    }

    private func notificationDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    private func date(from string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: string)
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let requestedDateString = userInfo["saintDate"] as? String
        let requestedDate = requestedDateString.flatMap { string in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            return formatter.date(from: string)
        } ?? Date()

        await MainActor.run {
            AppRouter.shared.openSaints(for: requestedDate)
        }
    }
}
