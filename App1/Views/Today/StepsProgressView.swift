import SwiftUI

struct StepsProgressView: View {
    let steps: Int
    let target: Int

    var progress: Double {
        min(Double(steps) / Double(target), 1.0)
    }

    var statusColor: Color {
        if steps >= target { return .green }
        if Double(steps) >= Double(target) * 0.7 { return .orange }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Steps", systemImage: "figure.walk")
                    .font(.body)

                Spacer()

                Text("\(steps.formatted()) / \(target.formatted())")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(statusColor)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(height: 10)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(statusColor.gradient)
                        .frame(width: geometry.size.width * progress, height: 10)
                        .animation(.spring(response: 0.5), value: progress)
                }
            }
            .frame(height: 10)

            if steps >= target {
                Label("Goal reached!", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 16)
    }
}
