import Foundation
import SwiftData

@Model
class BloodworkEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var hba1c: Double?
    var fastingGlucose: Double?
    var totalCholesterol: Double?
    var ldl: Double?
    var hdl: Double?
    var triglycerides: Double?
    var vitaminD: Double?
    var vitaminB12: Double?
    var tsh: Double?
    var systolicBP: Int?
    var diastolicBP: Int?
    var weight: Double?
    var notes: String?

    init(
        id: UUID = UUID(),
        date: Date = Date()
    ) {
        self.id = id
        self.date = date
    }

    struct ReferenceRange {
        let label: String
        let unit: String
        let min: Double?
        let max: Double?
        let southAsianAdjusted: Bool

        func status(for value: Double?) -> RangeStatus {
            guard let value else { return .unknown }
            if let min, value < min { return .low }
            if let max, value > max { return .high }
            return .normal
        }
    }

    enum RangeStatus: String {
        case low, normal, high, unknown

        var color: String {
            switch self {
            case .low: return "blue"
            case .normal: return "green"
            case .high: return "red"
            case .unknown: return "gray"
            }
        }
    }

    static let referenceRanges: [(keyPath: String, range: ReferenceRange)] = [
        ("hba1c", ReferenceRange(label: "HbA1c", unit: "%", min: nil, max: 5.7, southAsianAdjusted: false)),
        ("fastingGlucose", ReferenceRange(label: "Fasting Glucose", unit: "mg/dL", min: 70, max: 100, southAsianAdjusted: false)),
        ("totalCholesterol", ReferenceRange(label: "Total Cholesterol", unit: "mg/dL", min: nil, max: 200, southAsianAdjusted: false)),
        ("ldl", ReferenceRange(label: "LDL", unit: "mg/dL", min: nil, max: 100, southAsianAdjusted: false)),
        ("hdl", ReferenceRange(label: "HDL", unit: "mg/dL", min: 40, max: nil, southAsianAdjusted: false)),
        ("triglycerides", ReferenceRange(label: "Triglycerides", unit: "mg/dL", min: nil, max: 150, southAsianAdjusted: false)),
        ("vitaminD", ReferenceRange(label: "Vitamin D (25-OH)", unit: "ng/mL", min: 30, max: 100, southAsianAdjusted: false)),
        ("vitaminB12", ReferenceRange(label: "Vitamin B12", unit: "pg/mL", min: 200, max: 900, southAsianAdjusted: false)),
        ("tsh", ReferenceRange(label: "TSH", unit: "mIU/L", min: 0.4, max: 4.0, southAsianAdjusted: false))
    ]

    func value(for key: String) -> Double? {
        switch key {
        case "hba1c": return hba1c
        case "fastingGlucose": return fastingGlucose
        case "totalCholesterol": return totalCholesterol
        case "ldl": return ldl
        case "hdl": return hdl
        case "triglycerides": return triglycerides
        case "vitaminD": return vitaminD
        case "vitaminB12": return vitaminB12
        case "tsh": return tsh
        default: return nil
        }
    }

    // South Asian-adjusted BMI threshold: risk begins at 23 instead of 25
    static func bmiStatus(weight: Double, heightMeters: Double) -> (bmi: Double, status: RangeStatus) {
        let bmi = weight / (heightMeters * heightMeters)
        if bmi < 18.5 { return (bmi, .low) }
        if bmi < 23.0 { return (bmi, .normal) } // South Asian threshold
        return (bmi, .high)
    }
}
