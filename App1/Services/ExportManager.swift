import Foundation
import SwiftData

struct ExportManager {
    static func exportAsCSV(logs: [DailyLog]) -> String {
        var csv = "Date,Completion %,Calories,Protein (g),Steps,Sleep (h),Workout Type,Workout Duration (min),Weight (lbs),Drinks,Notes\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for log in logs.sorted(by: { $0.date < $1.date }) {
            let fields: [String] = [
                dateFormatter.string(from: log.date),
                String(format: "%.0f", log.completionPercentage * 100),
                log.caloriesLogged.map(String.init) ?? "",
                log.proteinLogged.map(String.init) ?? "",
                log.stepsCount.map(String.init) ?? "",
                log.sleepHours.map { String(format: "%.1f", $0) } ?? "",
                log.workoutType ?? "",
                log.workoutDuration.map(String.init) ?? "",
                log.weight.map { String(format: "%.1f", $0) } ?? "",
                log.drinksCount.map(String.init) ?? "",
                (log.notes ?? "").replacingOccurrences(of: ",", with: ";")
            ]
            csv += fields.joined(separator: ",") + "\n"
        }

        return csv
    }

    static func exportAsJSON(logs: [DailyLog]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        var entries: [[String: Any]] = []

        for log in logs.sorted(by: { $0.date < $1.date }) {
            var entry: [String: Any] = [
                "date": dateFormatter.string(from: log.date),
                "completionPercentage": Int(log.completionPercentage * 100)
            ]

            if let cal = log.caloriesLogged { entry["calories"] = cal }
            if let pro = log.proteinLogged { entry["protein"] = pro }
            if let steps = log.stepsCount { entry["steps"] = steps }
            if let sleep = log.sleepHours { entry["sleepHours"] = sleep }
            if let bedtime = log.bedtime { entry["bedtime"] = timeFormatter.string(from: bedtime) }
            if let wake = log.wakeTime { entry["wakeTime"] = timeFormatter.string(from: wake) }
            if let wType = log.workoutType { entry["workoutType"] = wType }
            if let wDur = log.workoutDuration { entry["workoutDuration"] = wDur }
            if let weight = log.weight { entry["weight"] = weight }
            if let drinks = log.drinksCount { entry["drinks"] = drinks }
            if let notes = log.notes { entry["notes"] = notes }

            let checklist = log.checklistItems.map { item -> [String: Any] in
                var dict: [String: Any] = [
                    "section": item.section,
                    "title": item.title,
                    "completed": item.isCompleted,
                    "autoFilled": item.isAutoFilled
                ]
                if let value = item.numericValue { dict["value"] = value }
                return dict
            }
            entry["checklist"] = checklist

            entries.append(entry)
        }

        let wrapper: [String: Any] = [
            "appName": "HealthCheck",
            "exportDate": dateFormatter.string(from: Date()),
            "entries": entries
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: wrapper, options: .prettyPrinted),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return jsonString
    }

    static func writeToTempFile(content: String, filename: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }
}
