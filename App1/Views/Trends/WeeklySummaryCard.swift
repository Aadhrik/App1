import SwiftUI

struct WeeklySummaryCard: View {
    let weekStart: Date
    let avgCompletion: Double
    let avgSleep: Double
    let avgSteps: Int
    let gymSessions: Int
    let activeDays: Int

    private var weekLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let startStr = formatter.string(from: weekStart)
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let endStr = formatter.string(from: endDate)
        return "\(startStr) - \(endStr)"
    }

    private var isCurrentWeek: Bool {
        let calendar = Calendar.current
        return calendar.isDate(weekStart, equalTo: Date(), toGranularity: .weekOfYear)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if isCurrentWeek {
                        Text("This Week")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    Text(weekLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                completionBadge
            }

            // Metrics grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                metricCell(
                    label: "Sleep",
                    value: String(format: "%.1fh", avgSleep),
                    icon: "bed.double.fill",
                    status: sleepStatus
                )
                metricCell(
                    label: "Steps",
                    value: formatSteps(avgSteps),
                    icon: "figure.walk",
                    status: stepsStatus
                )
                metricCell(
                    label: "Gym",
                    value: "\(gymSessions)x",
                    icon: "dumbbell.fill",
                    status: gymStatus
                )
            }

            // Active days bar
            HStack(spacing: 4) {
                Text("Active Days")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                ForEach(0..<7, id: \.self) { day in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(day < activeDays ? Color.teal : Color(.systemGray5))
                        .frame(width: 16, height: 6)
                }
                Text("\(activeDays)/7")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    private var completionBadge: some View {
        Text("\(Int(avgCompletion * 100))%")
            .font(.subheadline)
            .fontWeight(.bold)
            .foregroundStyle(statusColor(for: avgCompletion >= 0.8 ? .onTarget : (avgCompletion >= 0.5 ? .close : .offTarget)))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(statusColor(for: avgCompletion >= 0.8 ? .onTarget : (avgCompletion >= 0.5 ? .close : .offTarget)).opacity(0.15))
            )
    }

    @ViewBuilder
    private func metricCell(label: String, value: String, icon: String, status: MetricStatus) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(statusColor(for: status))
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(statusColor(for: status))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(statusColor(for: status).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formatSteps(_ steps: Int) -> String {
        if steps >= 1000 {
            return String(format: "%.1fk", Double(steps) / 1000.0)
        }
        return "\(steps)"
    }

    // MARK: - Status Evaluation

    private enum MetricStatus {
        case onTarget, close, offTarget
    }

    private var sleepStatus: MetricStatus {
        if avgSleep >= 7.0 && avgSleep <= 9.0 { return .onTarget }
        if avgSleep >= 6.0 { return .close }
        return .offTarget
    }

    private var stepsStatus: MetricStatus {
        if avgSteps >= 10000 { return .onTarget }
        if avgSteps >= 7000 { return .close }
        return .offTarget
    }

    private var gymStatus: MetricStatus {
        if gymSessions >= 3 { return .onTarget }
        if gymSessions >= 2 { return .close }
        return .offTarget
    }

    private func statusColor(for status: MetricStatus) -> Color {
        switch status {
        case .onTarget: return .green
        case .close: return .orange
        case .offTarget: return .red
        }
    }
}
