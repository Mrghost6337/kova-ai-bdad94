import Foundation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

enum HapticService {
    static func selection() {
        #if canImport(UIKit)
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    static func setCompleted() {
        #if canImport(UIKit)
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    static func restFinished() {
        #if canImport(UIKit)
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }
}

enum NotificationService {
    static func scheduleDailyReminder(hour: Int, minute: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted: Bool
        do {
            granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
        guard granted else { return false }
        center.removePendingNotificationRequests(withIdentifiers: ["kova.daily.workout"])
        let content = UNMutableNotificationContent()
        content.title = "Your session is ready"
        content.body = "Open KOVA for a workout adjusted to your latest feedback."
        content.sound = .default
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "kova.daily.workout", content: content, trigger: trigger)
        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }
}
