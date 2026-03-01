import Foundation
import UserNotifications

@Observable
@MainActor
final class NotificationManager {
    private(set) var isAuthorized = false

    // MARK: - Permission

    func requestPermission() async {
        do {
            isAuthorized = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            isAuthorized = false
        }
    }

    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Quota Alerts

    func scheduleQuotaAlert(minutesRemaining: Int, tier: SubscriptionTier) {
        guard tier != .byok else { return }

        let content = UNMutableNotificationContent()
        content.sound = .default

        switch minutesRemaining {
        case 5:
            content.title = "5 Minutes Remaining"
            content.body = "You have 5 voice minutes left this month. Upgrade for more."
            content.categoryIdentifier = "QUOTA_LOW"
        case 1:
            content.title = "1 Minute Remaining"
            content.body = "Almost out of voice minutes. Upgrade to keep talking."
            content.categoryIdentifier = "QUOTA_CRITICAL"
        case 0:
            content.title = "Minutes Exhausted"
            content.body = "You've used all your voice minutes. Upgrade or wait until next month."
            content.categoryIdentifier = "QUOTA_EXHAUSTED"
        default:
            return
        }

        let request = UNNotificationRequest(
            identifier: "quota_\(minutesRemaining)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { _ in }
    }

    // MARK: - Badge

    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
    }

    // MARK: - Notification Categories

    func registerCategories() {
        let upgradeAction = UNNotificationAction(
            identifier: "UPGRADE_ACTION",
            title: "Upgrade",
            options: [.foreground]
        )

        let dismissAction = UNNotificationAction(
            identifier: "DISMISS_ACTION",
            title: "Dismiss",
            options: []
        )

        let quotaLow = UNNotificationCategory(
            identifier: "QUOTA_LOW",
            actions: [upgradeAction, dismissAction],
            intentIdentifiers: []
        )

        let quotaCritical = UNNotificationCategory(
            identifier: "QUOTA_CRITICAL",
            actions: [upgradeAction, dismissAction],
            intentIdentifiers: []
        )

        let quotaExhausted = UNNotificationCategory(
            identifier: "QUOTA_EXHAUSTED",
            actions: [upgradeAction],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            quotaLow,
            quotaCritical,
            quotaExhausted,
        ])
    }
}
