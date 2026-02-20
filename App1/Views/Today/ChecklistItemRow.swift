import SwiftUI

struct ChecklistItemRow: View {
    @Bindable var item: ChecklistEntry
    var onToggle: () -> Void

    @State private var checkScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                    .strikethrough(item.isCompleted, color: .secondary)

                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if item.isAutoFilled {
                    Label("Auto-filled from Health", systemImage: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(.pink.opacity(0.7))
                }
            }

            Spacer()

            if let value = item.numericValue, item.itemType == "auto" || item.itemType == "numeric" {
                statusBadge(for: item)
            }

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    item.isCompleted.toggle()
                    checkScale = 1.3
                    onToggle()
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.1)) {
                    checkScale = 1.0
                }
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isCompleted ? Color.accentColor : .gray.opacity(0.4))
                    .scaleEffect(checkScale)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: item.isCompleted)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func statusBadge(for item: ChecklistEntry) -> some View {
        let color: Color = {
            switch item.statusColor {
            case .green: return .green
            case .yellow: return .orange
            case .red: return .red
            case .neutral: return .secondary
            }
        }()

        if let value = item.numericValue {
            Text(formatValue(value, for: item))
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.15))
                .foregroundStyle(color)
                .clipShape(Capsule())
        }
    }

    private func formatValue(_ value: Double, for item: ChecklistEntry) -> String {
        if item.title.contains("Sleep") {
            return String(format: "%.1fh", value)
        } else if item.title.contains("Steps") {
            return "\(Int(value).formatted())"
        } else {
            return "\(Int(value))"
        }
    }
}
