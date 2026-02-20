import SwiftUI
import SwiftData
import Charts

struct TrendsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyLog.date, order: .reverse) private var allLogs: [DailyLog]
    @Query private var allTargets: [UserTargets]

    @State private var healthKit = HealthKitManager.shared
    @State private var weightHistory: [(date: Date, value: Double)] = []
    @State private var stepsHistory: [(date: Date, value: Double)] = []
    @State private var isLoadingHealthKit = false

    private var targets: UserTargets {
        allTargets.first ?? UserTargets.defaults
    }

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if allLogs.isEmpty {
                        overallEmptyState
                    } else {
                        // Section 1: Calendar Heat Map
                        CalendarHeatMap(dailyLogs: allLogs)

                        // Section 2: Streak Counters
                        streaksSection

                        // Section 3: Weekly Summaries
                        weeklySummariesSection

                        // Section 4: Charts
                        chartsSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Trends")
        }
        .task {
            await loadHealthKitData()
        }
    }

    // MARK: - Empty State

    private var overallEmptyState: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "chart.bar.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.teal.opacity(0.4))

            Text("Your Trends Will Appear Here")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Start completing your daily checklist and your trends, streaks, and progress charts will show up here. Every day counts!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
                .frame(height: 40)
        }
    }

    // MARK: - Streaks Section

    private var streaksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Streaks")
                .font(.headline)
                .padding(.leading, 4)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StreakCard(
                    title: "Completion",
                    currentStreak: completionStreak.current,
                    longestStreak: completionStreak.longest,
                    icon: "checkmark.circle.fill"
                )

                StreakCard(
                    title: "Gym",
                    currentStreak: gymStreak.current,
                    longestStreak: gymStreak.longest,
                    icon: "dumbbell.fill"
                )

                StreakCard(
                    title: "Supplements",
                    currentStreak: supplementStreak.current,
                    longestStreak: supplementStreak.longest,
                    icon: "pills.fill"
                )

                StreakCard(
                    title: "Sleep Target",
                    currentStreak: sleepStreak.current,
                    longestStreak: sleepStreak.longest,
                    icon: "moon.fill"
                )
            }
        }
    }

    // MARK: - Weekly Summaries Section

    private var weeklySummariesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Summaries")
                .font(.headline)
                .padding(.leading, 4)

            if weekSummaries.isEmpty {
                weeklyEmptyState
            } else {
                ForEach(weekSummaries, id: \.weekStart) { summary in
                    WeeklySummaryCard(
                        weekStart: summary.weekStart,
                        avgCompletion: summary.avgCompletion,
                        avgSleep: summary.avgSleep,
                        avgSteps: summary.avgSteps,
                        gymSessions: summary.gymSessions,
                        activeDays: summary.activeDays
                    )
                }
            }
        }
    }

    private var weeklyEmptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.clock")
                .font(.title2)
                .foregroundStyle(Color(.systemGray3))
            Text("Complete a few more days to see weekly summaries")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    // MARK: - Charts Section

    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trends")
                .font(.headline)
                .padding(.leading, 4)

            // Weight Trend (from HealthKit)
            MetricChartView(
                title: "Weight",
                data: weightHistory,
                color: .purple,
                unit: "lbs"
            )

            // Daily Steps (weekly rolling average from HealthKit)
            MetricChartView(
                title: "Daily Steps (7-day avg)",
                data: rollingAverageSteps,
                color: .blue,
                unit: "steps"
            )

            // Sleep Duration (from DailyLog)
            MetricChartView(
                title: "Sleep Duration",
                data: sleepData,
                color: .indigo,
                unit: "hrs"
            )

            // Calories Logged
            MetricChartView(
                title: "Calories",
                data: caloriesData,
                color: .orange,
                unit: "cal"
            )

            // Protein Logged
            MetricChartView(
                title: "Protein",
                data: proteinData,
                color: .green,
                unit: "g"
            )
        }
    }

    // MARK: - HealthKit Data Loading

    private func loadHealthKitData() async {
        isLoadingHealthKit = true
        defer { isLoadingHealthKit = false }

        async let weightResult = healthKit.fetchWeightHistory(days: 90)
        async let stepsResult = healthKit.fetchDailySteps(days: 90)

        let (weights, steps) = await (weightResult, stepsResult)

        await MainActor.run {
            weightHistory = weights.map { (date: $0.date, value: $0.weight) }
            stepsHistory = steps.map { (date: $0.date, value: Double($0.steps)) }
        }
    }

    // MARK: - Chart Data

    private var rollingAverageSteps: [(date: Date, value: Double)] {
        guard stepsHistory.count >= 7 else {
            return stepsHistory
        }
        let sorted = stepsHistory.sorted { $0.date < $1.date }
        var result: [(date: Date, value: Double)] = []
        for i in 6..<sorted.count {
            let window = sorted[(i - 6)...i]
            let avg = window.map(\.value).reduce(0, +) / 7.0
            result.append((date: sorted[i].date, value: avg))
        }
        return result
    }

    private var sleepData: [(date: Date, value: Double)] {
        allLogs
            .filter { $0.sleepHours != nil }
            .sorted { $0.date < $1.date }
            .suffix(90)
            .map { (date: $0.date, value: $0.sleepHours ?? 0) }
    }

    private var caloriesData: [(date: Date, value: Double)] {
        allLogs
            .filter { $0.caloriesLogged != nil }
            .sorted { $0.date < $1.date }
            .suffix(90)
            .map { (date: $0.date, value: Double($0.caloriesLogged ?? 0)) }
    }

    private var proteinData: [(date: Date, value: Double)] {
        allLogs
            .filter { $0.proteinLogged != nil }
            .sorted { $0.date < $1.date }
            .suffix(90)
            .map { (date: $0.date, value: Double($0.proteinLogged ?? 0)) }
    }

    // MARK: - Streak Calculations

    private var sortedLogs: [DailyLog] {
        allLogs.sorted { $0.date > $1.date }
    }

    private var completionStreak: (current: Int, longest: Int) {
        calculateStreak { log in
            log.completionPercentage >= 0.8
        }
    }

    private var gymStreak: (current: Int, longest: Int) {
        // Gym streak: counts consecutive weeks (not days) with at least one gym session
        let weeklyGym = weeklyGymCounts()
        return calculateWeeklyStreak(weeklyGym) { count in count >= 1 }
    }

    private var supplementStreak: (current: Int, longest: Int) {
        calculateStreak { log in
            let supplementItems = log.checklistItems.filter { $0.section == "Supplements" }
            guard !supplementItems.isEmpty else { return false }
            return supplementItems.allSatisfy(\.isCompleted)
        }
    }

    private var sleepStreak: (current: Int, longest: Int) {
        calculateStreak { log in
            guard let sleep = log.sleepHours else { return false }
            return sleep >= targets.sleepHoursMin && sleep <= targets.sleepHoursMax
        }
    }

    private func calculateStreak(matching condition: (DailyLog) -> Bool) -> (current: Int, longest: Int) {
        let sorted = sortedLogs
        guard !sorted.isEmpty else { return (0, 0) }

        var currentStreak = 0
        var longestStreak = 0
        var countingCurrent = true

        let today = calendar.startOfDay(for: Date())

        for log in sorted {
            let logDay = calendar.startOfDay(for: log.date)
            let daysAgo = calendar.dateComponents([.day], from: logDay, to: today).day ?? 0

            // Only count consecutive days (allow today to be missing since it may be in-progress)
            if countingCurrent {
                if daysAgo == currentStreak || (currentStreak == 0 && daysAgo <= 1) {
                    if condition(log) {
                        currentStreak += 1
                    } else {
                        countingCurrent = false
                        longestStreak = max(longestStreak, currentStreak)
                    }
                } else if daysAgo > currentStreak + 1 {
                    // Gap in logs means streak is broken
                    countingCurrent = false
                    longestStreak = max(longestStreak, currentStreak)
                }
            }
        }

        // Scan all logs for longest streak
        longestStreak = max(longestStreak, currentStreak)
        var tempStreak = 0
        let chronological = allLogs.sorted { $0.date < $1.date }
        var previousDate: Date?

        for log in chronological {
            let logDay = calendar.startOfDay(for: log.date)
            if let prev = previousDate {
                let daysBetween = calendar.dateComponents([.day], from: prev, to: logDay).day ?? 0
                if daysBetween == 1 && condition(log) {
                    tempStreak += 1
                } else if daysBetween == 1 {
                    longestStreak = max(longestStreak, tempStreak)
                    tempStreak = 0
                } else {
                    longestStreak = max(longestStreak, tempStreak)
                    tempStreak = condition(log) ? 1 : 0
                }
            } else {
                tempStreak = condition(log) ? 1 : 0
            }
            previousDate = logDay
        }
        longestStreak = max(longestStreak, tempStreak)

        return (currentStreak, longestStreak)
    }

    private func weeklyGymCounts() -> [(weekStart: Date, count: Int)] {
        let sorted = allLogs.sorted { $0.date < $1.date }
        guard !sorted.isEmpty else { return [] }

        var weekMap: [Date: Int] = [:]
        for log in sorted {
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: log.date)?.start ?? log.date
            let hasGym = log.workoutType != nil || log.gymSplit != nil
            if hasGym {
                weekMap[weekStart, default: 0] += 1
            } else {
                // Ensure the week exists even with 0
                weekMap[weekStart] = weekMap[weekStart] ?? 0
            }
        }

        return weekMap.sorted { $0.key < $1.key }.map { (weekStart: $0.key, count: $0.value) }
    }

    private func calculateWeeklyStreak(_ weeks: [(weekStart: Date, count: Int)], condition: (Int) -> Bool) -> (current: Int, longest: Int) {
        guard !weeks.isEmpty else { return (0, 0) }

        var current = 0
        var longest = 0
        var tempStreak = 0

        for week in weeks.reversed() {
            if condition(week.count) {
                tempStreak += 1
            } else {
                if current == 0 { current = tempStreak }
                longest = max(longest, tempStreak)
                tempStreak = 0
            }
        }
        if current == 0 { current = tempStreak }
        longest = max(longest, tempStreak)

        return (current, longest)
    }

    // MARK: - Weekly Summary Data

    private struct WeekSummary {
        let weekStart: Date
        let avgCompletion: Double
        let avgSleep: Double
        let avgSteps: Int
        let gymSessions: Int
        let activeDays: Int
    }

    private var weekSummaries: [WeekSummary] {
        let today = calendar.startOfDay(for: Date())
        var summaries: [WeekSummary] = []

        for weekOffset in 0..<3 {
            guard let targetDate = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: today) else { continue }
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: targetDate) else { continue }
            let weekStart = weekInterval.start

            let logsThisWeek = allLogs.filter { log in
                let logDay = calendar.startOfDay(for: log.date)
                return logDay >= weekStart && logDay < weekInterval.end
            }

            guard !logsThisWeek.isEmpty else { continue }

            let avgCompletion = logsThisWeek.map(\.completionPercentage).reduce(0, +) / Double(logsThisWeek.count)

            let sleepLogs = logsThisWeek.compactMap(\.sleepHours)
            let avgSleep = sleepLogs.isEmpty ? 0 : sleepLogs.reduce(0, +) / Double(sleepLogs.count)

            let stepsLogs = logsThisWeek.compactMap(\.stepsCount)
            let avgSteps = stepsLogs.isEmpty ? 0 : stepsLogs.reduce(0, +) / stepsLogs.count

            let gymSessions = logsThisWeek.filter { $0.workoutType != nil || $0.gymSplit != nil }.count

            let activeDays = logsThisWeek.filter { $0.completionPercentage > 0 }.count

            summaries.append(WeekSummary(
                weekStart: weekStart,
                avgCompletion: avgCompletion,
                avgSleep: avgSleep,
                avgSteps: avgSteps,
                gymSessions: gymSessions,
                activeDays: activeDays
            ))
        }

        return summaries
    }
}
