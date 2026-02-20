import SwiftUI
import Charts

struct MetricChartView: View {
    let title: String
    let data: [(date: Date, value: Double)]
    let color: Color
    let unit: String

    private var latestValue: Double? {
        data.last?.value
    }

    private var minValue: Double {
        guard let min = data.map(\.value).min() else { return 0 }
        let padding = (data.map(\.value).max() ?? min - min) * 0.1
        return max(0, min - padding)
    }

    private var maxValue: Double {
        guard let max = data.map(\.value).max() else { return 100 }
        let padding = (max - (data.map(\.value).min() ?? 0)) * 0.1
        return max + padding
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                if let latest = latestValue {
                    Text(formattedValue(latest) + " " + unit)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(color)
                }
            }

            if data.count >= 2 {
                Chart {
                    ForEach(Array(data.enumerated()), id: \.offset) { index, point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value(title, point.value)
                        )
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value(title, point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    color.opacity(0.3),
                                    color.opacity(0.05)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartYScale(domain: minValue...maxValue)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: axisDayStride)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color(.systemGray4))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color(.systemGray4))
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(formattedValue(doubleValue))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 160)
            } else {
                emptyState
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title2)
                .foregroundStyle(Color(.systemGray3))
            Text("Not enough data yet")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Keep logging to see your trends")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
    }

    private var axisDayStride: Int {
        let dayCount = data.count
        if dayCount <= 14 { return 2 }
        if dayCount <= 30 { return 7 }
        return 14
    }

    private func formattedValue(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.0f", value)
        }
        if value == value.rounded() {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}
