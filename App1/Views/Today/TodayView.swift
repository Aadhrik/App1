import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allLogs: [DailyLog]
    @Query private var allTargets: [UserTargets]
    @Query private var allSupplements: [Supplement]
    @Query private var weeklyActivities: [WeeklyActivity]

    @State private var healthKit = HealthKitManager.shared
    @State private var checklistManager = ChecklistManager.shared
    @State private var showingAlcoholPrompt = false
    @State private var showingNotesSheet = false

    private var todayKey: String { DailyLog.dateKey(for: Date()) }

    private var todayLog: DailyLog? {
        allLogs.first { $0.dateString == todayKey }
    }

    private var targets: UserTargets {
        allTargets.first ?? UserTargets.defaults
    }

    private var currentWeekLogs: [DailyLog] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let weekStart = calendar.date(byAdding: .day, value: -(weekday - 1), to: today) ?? today
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? today
        return allLogs.filter { $0.date >= weekStart && $0.date < weekEnd }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let log = todayLog {
                        // Completion header
                        completionHeader(log: log)

                        // Health auto-fill data
                        if (log.stepsCount ?? 0) > 0 {
                            StepsProgressView(
                                steps: log.stepsCount ?? 0,
                                target: targets.dailySteps
                            )
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                        }

                        if log.sleepHours != nil {
                            SleepSummaryView(
                                sleepHours: log.sleepHours,
                                bedtime: log.bedtime,
                                wakeTime: log.wakeTime,
                                targetMin: targets.sleepHoursMin,
                                targetMax: targets.sleepHoursMax
                            )
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                        }

                        // Checklist sections
                        ForEach(DailyLog.sections, id: \.self) { section in
                            let items = log.itemsForSection(section)
                            if !items.isEmpty {
                                if section == "Weekly Activities" {
                                    weeklySection(log: log)
                                } else if section == "Nutrition" {
                                    nutritionSection(log: log, items: items)
                                } else {
                                    ChecklistSectionView(
                                        title: section,
                                        items: items,
                                        log: log,
                                        onToggle: { saveContext() }
                                    )
                                }
                            }
                        }

                        // Alcohol toggle
                        alcoholToggle(log: log)

                        // Notes
                        notesSection(log: log)

                    } else {
                        ProgressView("Setting up today's checklist...")
                            .padding(.top, 40)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await refreshData() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            await setupToday()
        }
    }

    // MARK: - Completion Header

    @ViewBuilder
    private func completionHeader(log: DailyLog) -> some View {
        VStack(spacing: 8) {
            Text(formattedDate())
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 8)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: log.completionPercentage)
                    .stroke(completionColor(log.completionPercentage), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5), value: log.completionPercentage)

                Text("\(Int(log.completionPercentage * 100))%")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(completionColor(log.completionPercentage))
            }

            Text("\(log.completedCount) of \(log.totalApplicableCount) completed")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Nutrition Section (with numeric inputs)

    @ViewBuilder
    private func nutritionSection(log: DailyLog, items: [ChecklistEntry]) -> some View {
        VStack(spacing: 0) {
            // Section header
            HStack(spacing: 10) {
                Image(systemName: "fork.knife")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24)

                Text("Nutrition")
                    .font(.headline)

                Spacer()

                let completion = log.completionForSection("Nutrition")
                Text("\(completion.completed)/\(completion.total)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().padding(.leading, 16)

            ForEach(items.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { item in
                if !item.isConditional || log.shouldShowConditionalItem(item) {
                    if item.title == "Calorie target" {
                        NumericInputRow(
                            title: item.title,
                            subtitle: item.subtitle,
                            targetMin: Double(targets.caloriesMin),
                            targetMax: Double(targets.caloriesMax),
                            unit: "cal",
                            value: Binding(
                                get: { log.caloriesLogged },
                                set: { newVal in
                                    log.caloriesLogged = newVal
                                    item.numericValue = newVal.map(Double.init)
                                    item.isCompleted = newVal != nil
                                }
                            ),
                            onChanged: { saveContext() }
                        )
                    } else if item.title == "Protein target" {
                        NumericInputRow(
                            title: item.title,
                            subtitle: item.subtitle,
                            targetMin: Double(targets.proteinMin),
                            targetMax: Double(targets.proteinMax),
                            unit: "g",
                            value: Binding(
                                get: { log.proteinLogged },
                                set: { newVal in
                                    log.proteinLogged = newVal
                                    item.numericValue = newVal.map(Double.init)
                                    item.isCompleted = newVal != nil
                                }
                            ),
                            onChanged: { saveContext() }
                        )
                    } else {
                        ChecklistItemRow(item: item) { saveContext() }
                    }

                    Divider().padding(.leading, 16)
                }
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    // MARK: - Weekly Section

    @ViewBuilder
    private func weeklySection(log: DailyLog) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24)

                Text("Weekly Activities")
                    .font(.headline)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().padding(.leading, 16)

            WeeklyActivityTracker(
                activities: weeklyActivities,
                weekLogs: currentWeekLogs
            ) { activityName, split in
                logWeeklyActivity(log: log, name: activityName, split: split)
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    // MARK: - Alcohol Toggle

    @ViewBuilder
    private func alcoholToggle(log: DailyLog) -> some View {
        VStack(spacing: 8) {
            Toggle(isOn: Binding(
                get: { log.hadAlcohol },
                set: { newVal in
                    log.hadAlcohol = newVal
                    saveContext()
                }
            )) {
                Label("Had drinks today?", systemImage: "wineglass")
                    .font(.subheadline)
            }
            .tint(Color.accentColor)

            if log.hadAlcohol {
                HStack {
                    Text("Number of drinks:")
                        .font(.caption)

                    Stepper(
                        value: Binding(
                            get: { log.drinksCount ?? 0 },
                            set: { log.drinksCount = $0; saveContext() }
                        ),
                        in: 0...20
                    ) {
                        Text("\(log.drinksCount ?? 0)")
                            .fontWeight(.medium)
                    }
                }

                Text("Remember to alternate with water")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    // MARK: - Notes

    @ViewBuilder
    private func notesSection(log: DailyLog) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notes", systemImage: "note.text")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Add notes for today...", text: Binding(
                get: { log.notes ?? "" },
                set: { log.notes = $0.isEmpty ? nil : $0; saveContext() }
            ), axis: .vertical)
            .lineLimit(3...6)
            .textFieldStyle(.plain)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    // MARK: - Helpers

    private func setupToday() async {
        // Ensure targets exist
        if allTargets.isEmpty {
            modelContext.insert(UserTargets.defaults)
        }

        // Ensure supplements exist
        if allSupplements.isEmpty {
            for supplement in Supplement.defaults {
                modelContext.insert(supplement)
            }
        }

        // Ensure weekly activities exist
        if weeklyActivities.isEmpty {
            for activity in WeeklyActivity.defaults {
                modelContext.insert(activity)
            }
        }

        // Create today's log if needed
        if todayLog == nil {
            let log = DailyLog(date: Date())
            modelContext.insert(log)
            try? modelContext.save()

            // Build checklist
            checklistManager.buildDailyChecklist(for: log, targets: targets, supplements: allSupplements)
            try? modelContext.save()
        }

        // Request HealthKit authorization and fetch data
        await healthKit.requestAuthorization()
        await refreshData()
    }

    private func refreshData() async {
        await healthKit.refreshTodayData()

        if let log = todayLog {
            checklistManager.autoFillFromHealthKit(log: log, targets: targets, healthKit: healthKit)
            saveContext()
        }
    }

    private func logWeeklyActivity(log: DailyLog, name: String, split: String?) {
        if name.contains("Gym") {
            log.gymSplit = split
            log.workoutDetected = true
            log.workoutType = split.map { "Gym - \($0)" } ?? "Gym"
        } else if name.contains("Basketball") {
            log.playedBasketball = true
        } else if name.contains("Pickleball") {
            log.playedPickleball = true
        }
        saveContext()
    }

    private func saveContext() {
        try? modelContext.save()
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    private func completionColor(_ percentage: Double) -> Color {
        if percentage >= 0.8 { return .green }
        if percentage >= 0.5 { return .orange }
        return .red
    }
}
