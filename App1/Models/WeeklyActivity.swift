import Foundation
import SwiftData

@Model
class WeeklyActivity {
    var name: String
    var targetFrequency: Int
    var icon: String // SF Symbol name
    var isActive: Bool
    var sortOrder: Int

    init(name: String, targetFrequency: Int, icon: String, isActive: Bool = true, sortOrder: Int = 0) {
        self.name = name
        self.targetFrequency = targetFrequency
        self.icon = icon
        self.isActive = isActive
        self.sortOrder = sortOrder
    }

    static var defaults: [WeeklyActivity] {
        [
            WeeklyActivity(name: "Gym (Push/Pull/Legs)", targetFrequency: 3, icon: "figure.strengthtraining.traditional", sortOrder: 0),
            WeeklyActivity(name: "Basketball", targetFrequency: 1, icon: "basketball", sortOrder: 1),
            WeeklyActivity(name: "Pickleball", targetFrequency: 1, icon: "figure.pickleball", sortOrder: 2)
        ]
    }
}
