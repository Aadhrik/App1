import Foundation
import SwiftData

@Model
class ChecklistEntry {
    @Attribute(.unique) var id: UUID
    var section: String
    var title: String
    var subtitle: String?
    var isCompleted: Bool
    var isAutoFilled: Bool
    var sortOrder: Int
    var itemType: String // "checkbox", "numeric", "auto", "optional", "counter"
    var numericValue: Double?
    var targetMin: Double?
    var targetMax: Double?
    var isConditional: Bool // only show under certain conditions
    var conditionKey: String? // e.g., "workoutDetected", "hadDrinks"
    var dailyLogDate: Date?

    init(
        id: UUID = UUID(),
        section: String,
        title: String,
        subtitle: String? = nil,
        isCompleted: Bool = false,
        isAutoFilled: Bool = false,
        sortOrder: Int = 0,
        itemType: String = "checkbox",
        numericValue: Double? = nil,
        targetMin: Double? = nil,
        targetMax: Double? = nil,
        isConditional: Bool = false,
        conditionKey: String? = nil,
        dailyLogDate: Date? = nil
    ) {
        self.id = id
        self.section = section
        self.title = title
        self.subtitle = subtitle
        self.isCompleted = isCompleted
        self.isAutoFilled = isAutoFilled
        self.sortOrder = sortOrder
        self.itemType = itemType
        self.numericValue = numericValue
        self.targetMin = targetMin
        self.targetMax = targetMax
        self.isConditional = isConditional
        self.conditionKey = conditionKey
        self.dailyLogDate = dailyLogDate
    }

    var statusColor: StatusColor {
        guard let value = numericValue, let min = targetMin, let max = targetMax else {
            return isCompleted ? .green : .neutral
        }
        if value >= min && value <= max { return .green }
        let lowerBuffer = min * 0.1
        let upperBuffer = max * 0.1
        if value >= (min - lowerBuffer) && value <= (max + upperBuffer) { return .yellow }
        return .red
    }

    enum StatusColor: String {
        case green, yellow, red, neutral
    }
}
