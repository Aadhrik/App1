import SwiftUI
import SwiftData

@main
struct HealthCheckApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DailyLog.self,
            ChecklistEntry.self,
            UserTargets.self,
            Supplement.self,
            WeeklyActivity.self,
            BloodworkEntry.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
