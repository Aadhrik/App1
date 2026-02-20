import SwiftUI
import SwiftData

struct WeeklyActivityTracker: View {
    let activities: [WeeklyActivity]
    let weekLogs: [DailyLog]
    var onLogActivity: (String, String?) -> Void

    @State private var showingSplitPicker = false
    private let gymSplits = ["Push", "Pull", "Legs"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(activities.filter(\.isActive).sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.name) { activity in
                activityRow(activity)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func activityRow(_ activity: WeeklyActivity) -> some View {
        let count = countForActivity(activity)

        HStack(spacing: 12) {
            Image(systemName: activity.icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.name)
                    .font(.body)

                Text("\(count) / \(activity.targetFrequency)x this week")
                    .font(.caption)
                    .foregroundStyle(count >= activity.targetFrequency ? .green : .secondary)
            }

            Spacer()

            // Progress dots
            HStack(spacing: 4) {
                ForEach(0..<activity.targetFrequency, id: \.self) { index in
                    Circle()
                        .fill(index < count ? Color.accentColor : Color(.systemGray4))
                        .frame(width: 10, height: 10)
                }
            }

            if activity.name.contains("Gym") {
                Menu {
                    ForEach(gymSplits, id: \.self) { split in
                        Button(split) {
                            onLogActivity(activity.name, split)
                        }
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                }
            } else {
                Button {
                    onLogActivity(activity.name, nil)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func countForActivity(_ activity: WeeklyActivity) -> Int {
        if activity.name.contains("Gym") {
            return weekLogs.filter { $0.gymSplit != nil }.count
        } else if activity.name.contains("Basketball") {
            return weekLogs.filter(\.playedBasketball).count
        } else if activity.name.contains("Pickleball") {
            return weekLogs.filter(\.playedPickleball).count
        }
        return 0
    }
}
