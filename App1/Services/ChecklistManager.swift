import Foundation
import SwiftData

@Observable
class ChecklistManager {
    static let shared = ChecklistManager()

    func buildDailyChecklist(for log: DailyLog, targets: UserTargets, supplements: [Supplement]) {
        guard log.checklistItems.isEmpty else { return }

        var items: [ChecklistEntry] = []

        // Morning section
        items.append(ChecklistEntry(section: "Morning", title: "Wake up on time", subtitle: "Within 30 min of \(formatTime(hour: targets.targetWakeTimeHour, minute: targets.targetWakeTimeMinute))", sortOrder: 0))
        items.append(ChecklistEntry(section: "Morning", title: "Morning water", subtitle: "Full glass of water on waking", sortOrder: 1))
        items.append(ChecklistEntry(section: "Morning", title: "High-protein breakfast", subtitle: "~350 cal, ~35g protein", sortOrder: 2))
        items.append(ChecklistEntry(section: "Morning", title: "Black coffee only", subtitle: "No sugary drinks", sortOrder: 3))

        // Supplements section
        for (index, supplement) in supplements.filter({ $0.isActive }).sorted(by: { $0.sortOrder < $1.sortOrder }).enumerated() {
            items.append(ChecklistEntry(
                section: "Supplements",
                title: supplement.name,
                subtitle: supplement.dosage,
                sortOrder: index
            ))
        }

        // Nutrition section
        items.append(ChecklistEntry(section: "Nutrition", title: "Log meals in Calori", subtitle: "Aim for 4-5 days/week", sortOrder: 0))
        items.append(ChecklistEntry(section: "Nutrition", title: "Calorie target", subtitle: "\(targets.caloriesMin)-\(targets.caloriesMax) cal", sortOrder: 1, itemType: "numeric", targetMin: Double(targets.caloriesMin), targetMax: Double(targets.caloriesMax)))
        items.append(ChecklistEntry(section: "Nutrition", title: "Protein target", subtitle: "\(targets.proteinMin)-\(targets.proteinMax)g", sortOrder: 2, itemType: "numeric", targetMin: Double(targets.proteinMin), targetMax: Double(targets.proteinMax)))
        items.append(ChecklistEntry(section: "Nutrition", title: "Water before meals", subtitle: "Drank water before each meal", sortOrder: 3))
        items.append(ChecklistEntry(section: "Nutrition", title: "Restaurant rules followed", subtitle: "Protein first, sauce on side, one starch, half portions", sortOrder: 4))
        items.append(ChecklistEntry(section: "Nutrition", title: "No liquid calories", subtitle: "Water, black coffee, unsweetened tea only", sortOrder: 5))
        items.append(ChecklistEntry(section: "Nutrition", title: "Alcohol moderation", subtitle: "Alternate with water", sortOrder: 6, itemType: "optional", isConditional: true, conditionKey: "hadDrinks"))

        // Movement section
        items.append(ChecklistEntry(section: "Movement", title: "Steps", subtitle: "Target: \(targets.dailySteps.formatted())", sortOrder: 0, itemType: "auto"))
        items.append(ChecklistEntry(section: "Movement", title: "Workout completed", subtitle: "Auto-detected from Apple Health", sortOrder: 1, itemType: "auto"))
        items.append(ChecklistEntry(section: "Movement", title: "Dynamic warmup", subtitle: "Before workout", sortOrder: 2, isConditional: true, conditionKey: "workoutDetected"))
        items.append(ChecklistEntry(section: "Movement", title: "Static stretching", subtitle: "After workout", sortOrder: 3, isConditional: true, conditionKey: "workoutDetected"))
        items.append(ChecklistEntry(section: "Movement", title: "Mobility work", subtitle: "Hip flexor openers + thoracic spine rotations", sortOrder: 4))

        // Evening / Sleep section
        items.append(ChecklistEntry(section: "Evening / Sleep", title: "No caffeine after 2 PM", sortOrder: 0))
        items.append(ChecklistEntry(section: "Evening / Sleep", title: "Phone on DND 30 min before bed", sortOrder: 1))
        items.append(ChecklistEntry(section: "Evening / Sleep", title: "Dim lights after 9 PM", sortOrder: 2))
        items.append(ChecklistEntry(section: "Evening / Sleep", title: "Wind-down activity", subtitle: "Audiobook/podcast via Libby with sleep timer", sortOrder: 3))
        items.append(ChecklistEntry(section: "Evening / Sleep", title: "Room temp 65-68°F", sortOrder: 4))
        items.append(ChecklistEntry(section: "Evening / Sleep", title: "Sleep duration", subtitle: "Target: \(String(format: "%.0f", targets.sleepHoursMin))-\(String(format: "%.0f", targets.sleepHoursMax))h", sortOrder: 5, itemType: "auto"))
        items.append(ChecklistEntry(section: "Evening / Sleep", title: "Bedtime consistency", subtitle: "Within 30 min of \(formatTime(hour: targets.targetBedtimeHour, minute: targets.targetBedtimeMinute))", sortOrder: 6, itemType: "auto"))

        // Set date reference for all items
        for item in items {
            item.dailyLogDate = log.date
        }

        log.checklistItems = items
    }

    func autoFillFromHealthKit(log: DailyLog, targets: UserTargets, healthKit: HealthKitManager) {
        // Steps
        if let stepsItem = log.checklistItems.first(where: { $0.section == "Movement" && $0.title == "Steps" }) {
            log.stepsCount = healthKit.todaySteps
            stepsItem.numericValue = Double(healthKit.todaySteps)
            if healthKit.todaySteps >= targets.dailySteps {
                stepsItem.isCompleted = true
                stepsItem.isAutoFilled = true
            }
        }

        // Workout
        if let workoutItem = log.checklistItems.first(where: { $0.section == "Movement" && $0.title == "Workout completed" }) {
            if healthKit.todayWorkoutDetected {
                workoutItem.isCompleted = true
                workoutItem.isAutoFilled = true
                log.workoutDetected = true
                log.workoutType = healthKit.todayWorkoutType
                log.workoutDuration = healthKit.todayWorkoutDuration
                workoutItem.subtitle = "\(healthKit.todayWorkoutType ?? "Workout") - \(healthKit.todayWorkoutDuration) min"
            }
        }

        // Sleep duration
        if let sleepItem = log.checklistItems.first(where: { $0.section == "Evening / Sleep" && $0.title == "Sleep duration" }) {
            if healthKit.todaySleepHours > 0 {
                log.sleepHours = healthKit.todaySleepHours
                sleepItem.numericValue = healthKit.todaySleepHours
                sleepItem.subtitle = String(format: "%.1f hours", healthKit.todaySleepHours)
                sleepItem.targetMin = targets.sleepHoursMin
                sleepItem.targetMax = targets.sleepHoursMax
                if healthKit.todaySleepHours >= targets.sleepHoursMin {
                    sleepItem.isCompleted = true
                    sleepItem.isAutoFilled = true
                }
            }
        }

        // Bedtime consistency
        if let bedtimeItem = log.checklistItems.first(where: { $0.section == "Evening / Sleep" && $0.title == "Bedtime consistency" }) {
            if let bedtime = healthKit.todayBedtime {
                log.bedtime = bedtime
                let calendar = Calendar.current
                let bedHour = calendar.component(.hour, from: bedtime)
                let bedMinute = calendar.component(.minute, from: bedtime)
                let targetMinutes = targets.targetBedtimeHour * 60 + targets.targetBedtimeMinute
                let actualMinutes = bedHour * 60 + bedMinute
                let diff = abs(actualMinutes - targetMinutes)
                if diff <= 30 || (1440 - diff) <= 30 { // handle midnight wrapping
                    bedtimeItem.isCompleted = true
                    bedtimeItem.isAutoFilled = true
                }
            }
        }

        // Wake time
        if let wakeItem = log.checklistItems.first(where: { $0.section == "Morning" && $0.title == "Wake up on time" }) {
            if let wakeTime = healthKit.todayWakeTime {
                log.wakeTime = wakeTime
                let calendar = Calendar.current
                let wakeHour = calendar.component(.hour, from: wakeTime)
                let wakeMinute = calendar.component(.minute, from: wakeTime)
                let targetMinutes = targets.targetWakeTimeHour * 60 + targets.targetWakeTimeMinute
                let actualMinutes = wakeHour * 60 + wakeMinute
                let diff = abs(actualMinutes - targetMinutes)
                if diff <= 30 {
                    wakeItem.isCompleted = true
                    wakeItem.isAutoFilled = true
                }
            }
        }

        // Weight
        if healthKit.latestWeight > 0 {
            log.weight = healthKit.latestWeight
        }

        // Resting heart rate
        if healthKit.todayRestingHeartRate > 0 {
            log.restingHeartRate = healthKit.todayRestingHeartRate
        }
    }

    private func formatTime(hour: Int, minute: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? Date()
        return formatter.string(from: date)
    }
}
