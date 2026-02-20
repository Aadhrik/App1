import Foundation
import SwiftData

@Model
class DailyLog {
    @Attribute(.unique) var dateString: String // "yyyy-MM-dd" for uniqueness
    var date: Date
    var caloriesLogged: Int?
    var proteinLogged: Int?
    var stepsCount: Int?
    var sleepHours: Double?
    var bedtime: Date?
    var wakeTime: Date?
    var workoutType: String?
    var workoutDuration: Int?
    var drinksCount: Int?
    var weight: Double?
    var restingHeartRate: Double?
    var notes: String?
    var hadAlcohol: Bool
    var workoutDetected: Bool

    // Weekly activity tracking
    var gymSplit: String? // "Push", "Pull", "Legs"
    var playedBasketball: Bool
    var playedPickleball: Bool

    @Relationship(deleteRule: .cascade)
    var checklistItems: [ChecklistEntry]

    init(date: Date) {
        self.date = Calendar.current.startOfDay(for: date)
        self.dateString = DailyLog.dateKey(for: date)
        self.checklistItems = []
        self.hadAlcohol = false
        self.workoutDetected = false
        self.playedBasketball = false
        self.playedPickleball = false
    }

    var completionPercentage: Double {
        let applicableItems = checklistItems.filter { !$0.isConditional || shouldShowConditionalItem($0) }
        guard !applicableItems.isEmpty else { return 0 }
        let completed = applicableItems.filter(\.isCompleted).count
        return Double(completed) / Double(applicableItems.count)
    }

    var completedCount: Int {
        checklistItems.filter(\.isCompleted).count
    }

    var totalApplicableCount: Int {
        checklistItems.filter { !$0.isConditional || shouldShowConditionalItem($0) }.count
    }

    func shouldShowConditionalItem(_ item: ChecklistEntry) -> Bool {
        switch item.conditionKey {
        case "workoutDetected":
            return workoutDetected
        case "hadDrinks":
            return hadAlcohol
        default:
            return true
        }
    }

    func itemsForSection(_ section: String) -> [ChecklistEntry] {
        checklistItems
            .filter { $0.section == section }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func completionForSection(_ section: String) -> (completed: Int, total: Int) {
        let items = itemsForSection(section).filter { !$0.isConditional || shouldShowConditionalItem($0) }
        let completed = items.filter(\.isCompleted).count
        return (completed, items.count)
    }

    static func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static let sections = ["Morning", "Supplements", "Nutrition", "Movement", "Evening / Sleep", "Weekly Activities"]
}
