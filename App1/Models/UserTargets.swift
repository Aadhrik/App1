import Foundation
import SwiftData

@Model
class UserTargets {
    var caloriesMin: Int
    var caloriesMax: Int
    var proteinMin: Int
    var proteinMax: Int
    var dailySteps: Int
    var sleepHoursMin: Double
    var sleepHoursMax: Double
    var gymSessionsPerWeek: Int
    var targetBedtimeHour: Int
    var targetBedtimeMinute: Int
    var targetWakeTimeHour: Int
    var targetWakeTimeMinute: Int
    var hasCompletedSetup: Bool

    init(
        caloriesMin: Int = 1800,
        caloriesMax: Int = 2000,
        proteinMin: Int = 140,
        proteinMax: Int = 160,
        dailySteps: Int = 10000,
        sleepHoursMin: Double = 7.0,
        sleepHoursMax: Double = 8.0,
        gymSessionsPerWeek: Int = 3,
        targetBedtimeHour: Int = 23,
        targetBedtimeMinute: Int = 0,
        targetWakeTimeHour: Int = 7,
        targetWakeTimeMinute: Int = 0,
        hasCompletedSetup: Bool = false
    ) {
        self.caloriesMin = caloriesMin
        self.caloriesMax = caloriesMax
        self.proteinMin = proteinMin
        self.proteinMax = proteinMax
        self.dailySteps = dailySteps
        self.sleepHoursMin = sleepHoursMin
        self.sleepHoursMax = sleepHoursMax
        self.gymSessionsPerWeek = gymSessionsPerWeek
        self.targetBedtimeHour = targetBedtimeHour
        self.targetBedtimeMinute = targetBedtimeMinute
        self.targetWakeTimeHour = targetWakeTimeHour
        self.targetWakeTimeMinute = targetWakeTimeMinute
        self.hasCompletedSetup = hasCompletedSetup
    }

    var caloriesRange: ClosedRange<Int> { caloriesMin...caloriesMax }
    var proteinRange: ClosedRange<Int> { proteinMin...proteinMax }
    var sleepHoursRange: ClosedRange<Double> { sleepHoursMin...sleepHoursMax }

    var targetBedtime: DateComponents {
        var components = DateComponents()
        components.hour = targetBedtimeHour
        components.minute = targetBedtimeMinute
        return components
    }

    var targetWakeTime: DateComponents {
        var components = DateComponents()
        components.hour = targetWakeTimeHour
        components.minute = targetWakeTimeMinute
        return components
    }

    static var defaults: UserTargets {
        UserTargets()
    }
}
