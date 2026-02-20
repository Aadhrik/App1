import SwiftUI

struct SleepSummaryView: View {
    let sleepHours: Double?
    let bedtime: Date?
    let wakeTime: Date?
    let targetMin: Double
    let targetMax: Double

    private var statusColor: Color {
        guard let hours = sleepHours else { return .secondary }
        if hours >= targetMin && hours <= targetMax { return .green }
        if hours >= targetMin - 0.5 { return .orange }
        return .red
    }

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Sleep", systemImage: "moon.fill")
                    .font(.body)

                Spacer()

                if let hours = sleepHours {
                    Text(String(format: "%.1f hours", hours))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(statusColor)
                } else {
                    Text("No data")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let hours = sleepHours {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray5))
                            .frame(height: 10)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(statusColor.gradient)
                            .frame(width: geometry.size.width * min(hours / targetMax, 1.0), height: 10)
                            .animation(.spring(response: 0.5), value: hours)
                    }
                }
                .frame(height: 10)
            }

            HStack(spacing: 16) {
                if let bedtime {
                    Label(timeFormatter.string(from: bedtime), systemImage: "bed.double.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let wakeTime {
                    Label(timeFormatter.string(from: wakeTime), systemImage: "sunrise.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 16)
    }
}
