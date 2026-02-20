import SwiftUI
import SwiftData

struct TargetsEditor: View {
    @Bindable var targets: UserTargets

    @State private var bedtimeDate: Date = Date()
    @State private var wakeTimeDate: Date = Date()

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Calories
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Minimum")
                            Spacer()
                            Text("\(targets.caloriesMin) cal")
                                .foregroundStyle(.secondary)
                        }
                        Stepper(value: $targets.caloriesMin, in: 1000...targets.caloriesMax, step: 50) {
                            EmptyView()
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Maximum")
                            Spacer()
                            Text("\(targets.caloriesMax) cal")
                                .foregroundStyle(.secondary)
                        }
                        Stepper(value: $targets.caloriesMax, in: targets.caloriesMin...3500, step: 50) {
                            EmptyView()
                        }
                    }
                } header: {
                    Label("Calories", systemImage: "flame")
                } footer: {
                    Text("Daily calorie target range: \(targets.caloriesMin)-\(targets.caloriesMax) cal")
                }

                // MARK: - Protein
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Minimum")
                            Spacer()
                            Text("\(targets.proteinMin) g")
                                .foregroundStyle(.secondary)
                        }
                        Stepper(value: $targets.proteinMin, in: 50...targets.proteinMax, step: 5) {
                            EmptyView()
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Maximum")
                            Spacer()
                            Text("\(targets.proteinMax) g")
                                .foregroundStyle(.secondary)
                        }
                        Stepper(value: $targets.proteinMax, in: targets.proteinMin...300, step: 5) {
                            EmptyView()
                        }
                    }
                } header: {
                    Label("Protein", systemImage: "fish")
                } footer: {
                    Text("Daily protein target range: \(targets.proteinMin)-\(targets.proteinMax) g")
                }

                // MARK: - Steps
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Daily Steps")
                            Spacer()
                            Text("\(targets.dailySteps.formatted())")
                                .foregroundStyle(.secondary)
                        }
                        Stepper(value: $targets.dailySteps, in: 1000...30000, step: 500) {
                            EmptyView()
                        }
                    }
                } header: {
                    Label("Steps", systemImage: "figure.walk")
                }

                // MARK: - Sleep
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Minimum Hours")
                            Spacer()
                            Text(String(format: "%.1f h", targets.sleepHoursMin))
                                .foregroundStyle(.secondary)
                        }
                        Stepper(value: $targets.sleepHoursMin, in: 4.0...targets.sleepHoursMax, step: 0.5) {
                            EmptyView()
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Maximum Hours")
                            Spacer()
                            Text(String(format: "%.1f h", targets.sleepHoursMax))
                                .foregroundStyle(.secondary)
                        }
                        Stepper(value: $targets.sleepHoursMax, in: targets.sleepHoursMin...12.0, step: 0.5) {
                            EmptyView()
                        }
                    }
                } header: {
                    Label("Sleep", systemImage: "moon.zzz")
                } footer: {
                    Text("Target sleep range: \(String(format: "%.1f", targets.sleepHoursMin))-\(String(format: "%.1f", targets.sleepHoursMax)) hours")
                }

                // MARK: - Gym
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Sessions per Week")
                            Spacer()
                            Text("\(targets.gymSessionsPerWeek)")
                                .foregroundStyle(.secondary)
                        }
                        Stepper(value: $targets.gymSessionsPerWeek, in: 1...7) {
                            EmptyView()
                        }
                    }
                } header: {
                    Label("Gym", systemImage: "figure.strengthtraining.traditional")
                }

                // MARK: - Bedtime
                Section {
                    DatePicker("Bedtime", selection: $bedtimeDate, displayedComponents: .hourAndMinute)
                        .onChange(of: bedtimeDate) { _, newValue in
                            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                            targets.targetBedtimeHour = components.hour ?? 23
                            targets.targetBedtimeMinute = components.minute ?? 0
                        }

                    DatePicker("Wake Time", selection: $wakeTimeDate, displayedComponents: .hourAndMinute)
                        .onChange(of: wakeTimeDate) { _, newValue in
                            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                            targets.targetWakeTimeHour = components.hour ?? 7
                            targets.targetWakeTimeMinute = components.minute ?? 0
                        }
                } header: {
                    Label("Sleep Schedule", systemImage: "bed.double")
                } footer: {
                    Text("Bedtime: \(formatTime(hour: targets.targetBedtimeHour, minute: targets.targetBedtimeMinute)) - Wake: \(formatTime(hour: targets.targetWakeTimeHour, minute: targets.targetWakeTimeMinute))")
                }
            }
            .navigationTitle("Edit Targets")
            .onAppear {
                bedtimeDate = dateFrom(hour: targets.targetBedtimeHour, minute: targets.targetBedtimeMinute)
                wakeTimeDate = dateFrom(hour: targets.targetWakeTimeHour, minute: targets.targetWakeTimeMinute)
            }
        }
    }

    // MARK: - Helpers

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
