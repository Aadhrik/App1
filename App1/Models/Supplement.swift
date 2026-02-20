import Foundation
import SwiftData

@Model
class Supplement {
    var name: String
    var dosage: String
    var timing: String // "morning", "evening", "anytime"
    var notes: String?
    var isActive: Bool
    var sortOrder: Int

    init(name: String, dosage: String, timing: String, notes: String? = nil, isActive: Bool = true, sortOrder: Int = 0) {
        self.name = name
        self.dosage = dosage
        self.timing = timing
        self.notes = notes
        self.isActive = isActive
        self.sortOrder = sortOrder
    }

    static var defaults: [Supplement] {
        [
            Supplement(name: "Vitamin D3 + K2", dosage: "2000-4000 IU D3 with K2", timing: "morning", sortOrder: 0),
            Supplement(name: "Vitamin B12", dosage: "500-1000 mcg methylcobalamin", timing: "morning", sortOrder: 1),
            Supplement(name: "Omega-3 Fish Oil", dosage: "1-2g EPA/DHA", timing: "morning", sortOrder: 2),
            Supplement(name: "Magnesium Glycinate", dosage: "300-400mg elemental magnesium", timing: "evening", notes: "Take before bed", sortOrder: 3)
        ]
    }
}
