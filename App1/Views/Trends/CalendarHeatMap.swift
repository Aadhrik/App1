import SwiftUI
import SwiftData

struct CalendarHeatMap: View {
    let dailyLogs: [DailyLog]

    @State private var selectedDay: DailyLog?
    @State private var showingDetail = false

    private let columns = 27 // ~6 months of weeks
    private let cellSize: CGFloat = 13
    private let cellSpacing: CGFloat = 3
    private let calendar = Calendar.current
    private let dayLabels = ["", "Mon", "", "Wed", "", "Fri", ""]

    private var heatMapData: [[DayCell]] {
        let today = calendar.startOfDay(for: Date())
        let totalDays = columns * 7

        // Build a lookup from dateString to DailyLog
        var logLookup: [String: DailyLog] = [:]
        for log in dailyLogs {
            logLookup[log.dateString] = log
        }

        // Find the start date: go back enough weeks so the grid ends on today's week
        let todayWeekday = calendar.component(.weekday, from: today) // 1=Sun, 7=Sat
        let daysFromSunday = todayWeekday - 1
        let endOfGrid = today
        guard let startOfGrid = calendar.date(byAdding: .day, value: -(totalDays - 1 - (6 - daysFromSunday)), to: endOfGrid) else {
            return []
        }
        // Align to Sunday
        let startWeekday = calendar.component(.weekday, from: startOfGrid)
        guard let alignedStart = calendar.date(byAdding: .day, value: -(startWeekday - 1), to: startOfGrid) else {
            return []
        }

        var grid: [[DayCell]] = Array(repeating: [], count: columns)

        for col in 0..<columns {
            var week: [DayCell] = []
            for row in 0..<7 {
                let dayOffset = col * 7 + row
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: alignedStart) else {
                    week.append(DayCell(date: Date(), completion: nil, isFuture: true))
                    continue
                }
                let isFuture = date > today
                let dateKey = DailyLog.dateKey(for: date)
                let log = logLookup[dateKey]
                week.append(DayCell(date: date, log: log, completion: log?.completionPercentage, isFuture: isFuture))
            }
            grid[col] = week
        }

        return grid
    }

    private var monthLabels: [(String, Int)] {
        guard let firstGrid = heatMapData.first, let firstCell = firstGrid.first else { return [] }
        var labels: [(String, Int)] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        var lastMonth = -1

        for col in 0..<heatMapData.count {
            guard let firstDayOfWeek = heatMapData[col].first else { continue }
            let month = calendar.component(.month, from: firstDayOfWeek.date)
            if month != lastMonth {
                labels.append((formatter.string(from: firstDayOfWeek.date), col))
                lastMonth = month
            }
        }
        return labels
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Completion")
                .font(.headline)

            // Month labels
            HStack(spacing: 0) {
                // Spacer for day labels
                VStack { Spacer() }
                    .frame(width: 30)

                GeometryReader { geo in
                    let totalWidth = CGFloat(columns) * (cellSize + cellSpacing)
                    ForEach(monthLabels, id: \.1) { label, col in
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .position(
                                x: CGFloat(col) * (cellSize + cellSpacing) + cellSize / 2,
                                y: 6
                            )
                    }
                }
                .frame(height: 14)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    // Day-of-week labels
                    VStack(alignment: .trailing, spacing: cellSpacing) {
                        ForEach(0..<7, id: \.self) { row in
                            Text(dayLabels[row])
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .frame(width: 26, height: cellSize, alignment: .trailing)
                        }
                    }
                    .padding(.trailing, 4)

                    // Grid
                    HStack(spacing: cellSpacing) {
                        ForEach(0..<heatMapData.count, id: \.self) { col in
                            VStack(spacing: cellSpacing) {
                                ForEach(0..<7, id: \.self) { row in
                                    let cell = heatMapData[col][row]
                                    cellView(for: cell)
                                }
                            }
                        }
                    }
                }
            }
            .defaultScrollAnchor(.trailing)

            // Legend
            HStack(spacing: 4) {
                Spacer()
                Text("Less")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorForCompletion(level))
                        .frame(width: cellSize, height: cellSize)
                }
                Text("More")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Selected day detail
            if let selected = selectedDay {
                selectedDayDetail(log: selected)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        .animation(.easeInOut(duration: 0.2), value: selectedDay?.dateString)
    }

    @ViewBuilder
    private func cellView(for cell: DayCell) -> some View {
        if cell.isFuture {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.clear)
                .frame(width: cellSize, height: cellSize)
        } else {
            RoundedRectangle(cornerRadius: 2)
                .fill(colorForCompletion(cell.completion))
                .frame(width: cellSize, height: cellSize)
                .onTapGesture {
                    withAnimation {
                        if selectedDay?.dateString == cell.log?.dateString {
                            selectedDay = nil
                        } else {
                            selectedDay = cell.log
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private func selectedDayDetail(log: DailyLog) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()

            HStack {
                Text(formattedDate(log.date))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(Int(log.completionPercentage * 100))% complete")
                    .font(.subheadline)
                    .foregroundStyle(completionColor(log.completionPercentage))
            }

            HStack(spacing: 16) {
                if let calories = log.caloriesLogged {
                    Label("\(calories) cal", systemImage: "flame")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let protein = log.proteinLogged {
                    Label("\(protein)g protein", systemImage: "fish")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let steps = log.stepsCount {
                    Label("\(steps) steps", systemImage: "figure.walk")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let sleep = log.sleepHours {
                    Label(String(format: "%.1fh sleep", sleep), systemImage: "bed.double")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func colorForCompletion(_ completion: Double?) -> Color {
        guard let completion else {
            return Color(.systemGray5)
        }
        if completion == 0 {
            return Color(.systemGray5)
        }
        // Teal accent with varying opacity based on completion
        return Color.teal.opacity(0.2 + (completion * 0.8))
    }

    private func completionColor(_ percentage: Double) -> Color {
        if percentage >= 0.8 { return .green }
        if percentage >= 0.5 { return .orange }
        return .red
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
}

private struct DayCell {
    let date: Date
    var log: DailyLog?
    var completion: Double?
    var isFuture: Bool
}
