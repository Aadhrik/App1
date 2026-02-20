import SwiftUI

struct NotificationSettings: View {
    var targets: UserTargets

    @State private var notificationManager = NotificationManager.shared

    @State private var supplementTime: Date = Date()
    @State private var mealLogTime: Date = Date()

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Authorization
                if !notificationManager.isAuthorized {
                    Section {
                        HStack {
                            Image(systemName: "bell.badge")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Notifications Not Enabled")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Tap to request notification permissions.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Enable") {
                                Task {
                                    await notificationManager.requestAuthorization()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }

                // MARK: - Supplement Reminder
                Section {
                    Toggle("Morning Supplements", isOn: $notificationManager.supplementReminderEnabled)
                        .onChange(of: notificationManager.supplementReminderEnabled) { _, _ in
                            saveAndSchedule()
                        }

                    if notificationManager.supplementReminderEnabled {
                        DatePicker(
                            "Reminder Time",
                            selection: $supplementTime,
                            displayedComponents: .hourAndMinute
                        )
                        .onChange(of: supplementTime) { _, newValue in
                            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                            notificationManager.supplementReminderHour = components.hour ?? 9
                            notificationManager.supplementReminderMinute = components.minute ?? 0
                            saveAndSchedule()
                        }
                    }
                } header: {
                    Label("Supplement Reminder", systemImage: "pill")
                } footer: {
                    Text("Reminds you to take D3+K2, B12, and Omega-3.")
                }

                // MARK: - Meal Log Reminder
                Section {
                    Toggle("Meal Logging", isOn: $notificationManager.mealLogReminderEnabled)
                        .onChange(of: notificationManager.mealLogReminderEnabled) { _, _ in
                            saveAndSchedule()
                        }

                    if notificationManager.mealLogReminderEnabled {
                        DatePicker(
                            "Reminder Time",
                            selection: $mealLogTime,
                            displayedComponents: .hourAndMinute
                        )
                        .onChange(of: mealLogTime) { _, newValue in
                            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                            notificationManager.mealLogReminderHour = components.hour ?? 14
                            notificationManager.mealLogReminderMinute = components.minute ?? 0
                            saveAndSchedule()
                        }
                    }
                } header: {
                    Label("Meal Log Reminder", systemImage: "fork.knife")
                } footer: {
                    Text("Reminds you to log meals in Calori.")
                }

                // MARK: - Wind Down Reminder
                Section {
                    Toggle("Wind Down", isOn: $notificationManager.windDownReminderEnabled)
                        .onChange(of: notificationManager.windDownReminderEnabled) { _, _ in
                            saveAndSchedule()
                        }
                } header: {
                    Label("Wind Down Reminder", systemImage: "moon")
                } footer: {
                    Text("Fires 30 minutes before your target bedtime (\(formatTime(hour: targets.targetBedtimeHour, minute: targets.targetBedtimeMinute))). Put phone on DND and dim lights.")
                }

                // MARK: - Magnesium Reminder
                Section {
                    Toggle("Magnesium Before Bed", isOn: $notificationManager.magnesiumReminderEnabled)
                        .onChange(of: notificationManager.magnesiumReminderEnabled) { _, _ in
                            saveAndSchedule()
                        }
                } header: {
                    Label("Magnesium Reminder", systemImage: "bed.double")
                } footer: {
                    Text("Reminds you at bedtime (\(formatTime(hour: targets.targetBedtimeHour, minute: targets.targetBedtimeMinute))) to take magnesium glycinate.")
                }
            }
            .navigationTitle("Notifications")
            .onAppear {
                notificationManager.loadSettings()
                supplementTime = dateFrom(
                    hour: notificationManager.supplementReminderHour,
                    minute: notificationManager.supplementReminderMinute
                )
                mealLogTime = dateFrom(
                    hour: notificationManager.mealLogReminderHour,
                    minute: notificationManager.mealLogReminderMinute
                )
            }
        }
    }

    // MARK: - Helpers

    private func saveAndSchedule() {
        notificationManager.saveSettings()
        notificationManager.scheduleAllNotifications(targets: targets)
    }

    private func dateFrom(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }

    private func formatTime(hour: Int, minute: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let date = dateFrom(hour: hour, minute: minute)
        return formatter.string(from: date)
    }
}
