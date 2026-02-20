import SwiftUI

struct ChecklistSectionView: View {
    let title: String
    let items: [ChecklistEntry]
    let log: DailyLog
    var onToggle: () -> Void

    @State private var isExpanded: Bool = true

    private var completedCount: Int {
        items.filter { !$0.isConditional || log.shouldShowConditionalItem($0) }
             .filter(\.isCompleted).count
    }

    private var totalCount: Int {
        items.filter { !$0.isConditional || log.shouldShowConditionalItem($0) }.count
    }

    private var isAllCompleted: Bool {
        totalCount > 0 && completedCount == totalCount
    }

    private var sectionIcon: String {
        switch title {
        case "Morning": return "sunrise.fill"
        case "Supplements": return "pills.fill"
        case "Nutrition": return "fork.knife"
        case "Movement": return "figure.run"
        case "Evening / Sleep": return "moon.stars.fill"
        case "Weekly Activities": return "calendar"
        default: return "checklist"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: sectionIcon)
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 24)

                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    if isAllCompleted {
                        Label("\(completedCount)/\(totalCount)", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Text("\(completedCount)/\(totalCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: isExpanded)

            if isExpanded {
                Divider()
                    .padding(.leading, 16)

                VStack(spacing: 0) {
                    ForEach(items.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { item in
                        if !item.isConditional || log.shouldShowConditionalItem(item) {
                            ChecklistItemRow(item: item) {
                                onToggle()
                            }

                            if item.id != items.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}
