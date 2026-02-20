import Foundation
import UserNotifications

@Observable
class NotificationManager {
    static let shared = NotificationManager()

    var isAuthorized = false

    // Notification toggles
    var supplementReminderEnabled = true
    var mealLogReminderEnabled = true
    var windDownReminderEnabled = true
    var magnesiumReminderEnabled = true

    // Notification times (stored as hour/minute)
    var supplementReminderHour = 9
    var supplementReminderMinute = 0
    var mealLogReminderHour = 14
    var mealLogReminderMinute = 0

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                isAuthorized = granted
            }
        } catch {
            await MainActor.run {
                isAuthorized = false
            }
        }
    }

    func scheduleAllNotifications(targets: UserTargets) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        if supplementReminderEnabled {
            scheduleNotification(
                id: "supplement-morning",
                title: "Morning Supplements",
                body: "Time to take your D3+K2, B12, and Omega-3",
                hour: supplementReminderHour,
                minute: supplementReminderMinute
            )
        }

        if mealLogReminderEnabled {
            scheduleNotification(
                id: "meal-log",
                title: "Log Your Meals",
                body: "Have you logged your meals in Calori today?",
                hour: mealLogReminderHour,
                minute: mealLogReminderMinute
            )
        }

        if windDownReminderEnabled {
            // 30 minutes before target bedtime
            var windDownHour = targets.targetBedtimeHour
            var windDownMinute = targets.targetBedtimeMinute - 30
            if windDownMinute < 0 {
                windDownMinute += 60
                windDownHour -= 1
                if windDownHour < 0 { windDownHour += 24 }
            }
            scheduleNotification(
                id: "wind-down",
                title: "Wind Down Time",
                body: "Start your wind-down routine. Put phone on DND and dim lights.",
                hour: windDownHour,
                minute: windDownMinute
            )
        }

        if magnesiumReminderEnabled {
            scheduleNotification(
                id: "magnesium",
                title: "Magnesium Time",
                body: "Take your magnesium glycinate before bed",
                hour: targets.targetBedtimeHour,
                minute: targets.targetBedtimeMinute
            )
        }
    }

    private func scheduleNotification(id: String, title: String, body: String, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { _ in }
    }

    func loadSettings() {
        let defaults = UserDefaults.standard
        supplementReminderEnabled = defaults.object(forKey: "notif.supplement") as? Bool ?? true
        mealLogReminderEnabled = defaults.object(forKey: "notif.mealLog") as? Bool ?? true
        windDownReminderEnabled = defaults.object(forKey: "notif.windDown") as? Bool ?? true
        magnesiumReminderEnabled = defaults.object(forKey: "notif.magnesium") as? Bool ?? true
        supplementReminderHour = defaults.object(forKey: "notif.supplementHour") as? Int ?? 9
        supplementReminderMinute = defaults.object(forKey: "notif.supplementMinute") as? Int ?? 0
        mealLogReminderHour = defaults.object(forKey: "notif.mealLogHour") as? Int ?? 14
        mealLogReminderMinute = defaults.object(forKey: "notif.mealLogMinute") as? Int ?? 0
    }

    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(supplementReminderEnabled, forKey: "notif.supplement")
        defaults.set(mealLogReminderEnabled, forKey: "notif.mealLog")
        defaults.set(windDownReminderEnabled, forKey: "notif.windDown")
        defaults.set(magnesiumReminderEnabled, forKey: "notif.magnesium")
        defaults.set(supplementReminderHour, forKey: "notif.supplementHour")
        defaults.set(supplementReminderMinute, forKey: "notif.supplementMinute")
        defaults.set(mealLogReminderHour, forKey: "notif.mealLogHour")
        defaults.set(mealLogReminderMinute, forKey: "notif.mealLogMinute")
    }
}
