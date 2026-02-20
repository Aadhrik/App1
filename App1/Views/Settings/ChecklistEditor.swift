import SwiftUI
import SwiftData

struct ChecklistEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allLogs: [DailyLog]

    private var todayLog: DailyLog? {
        let todayKey = DailyLog.dateKey(for: Date())
        return allLogs.first { $0.dateString == todayKey }
    }

    private var groupedItems: [(section: String, items: [ChecklistEntry])] {
        guard let log = todayLog else { return [] }
        return DailyLog.sections.compactMap { section in
            let items = log.itemsForSection(section)
            guard !items.isEmpty else { return nil }
            return (section: section, items: items)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if todayLog != nil {
                    ForEach(groupedItems, id: \.section) { group in
                        Section {
                            ForEach(group.items, id: \.id) { item in
                                ChecklistItemEditorRow(item: item) {
                                    try? modelContext.save()
                                }
                            }
                        } header: {
                            HStack {
                                Text(group.section)
                                Spacer()
                                Text("\(group.items.count) items")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                } else {
                    Section {
                        ContentUnavailableView {
                            Label("No Checklist Data", systemImage: "checklist")
                        } description: {
                            Text("Open the Today tab first to generate today's checklist.")
                        }
                    }
                }
            }
            .navigationTitle("Checklist Items")
        }
    }
}

// MARK: - Checklist Item Editor Row

private struct ChecklistItemEditorRow: View {
    @Bindable var item: ChecklistEntry
    let onChanged: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Type indicator
            Image(systemName: iconForType(item.itemType))
                .font(.subheadline)
                .foregroundStyle(colorForType(item.itemType))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body)

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Text(item.itemType.uppercased())
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    if item.isConditional {
                        Text("CONDITIONAL")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }

                    if item.isAutoFilled {
                        Text("AUTO")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            if item.isConditional {
                Toggle("", isOn: Binding(
                    get: { !item.isConditional || item.conditionKey != nil },
                    set: { newValue in
                        // Toggle conditional visibility is informational only;
                        // the conditionKey controls when it appears
                        onChanged()
                    }
                ))
                .labelsHidden()
                .disabled(true)
            }
        }
        .padding(.vertical, 2)
        .opacity(item.isConditional ? 0.7 : 1.0)
    }

    private func iconForType(_ type: String) -> String {
        switch type {
        case "checkbox": return "checkmark.square"
        case "numeric": return "number.square"
        case "auto": return "gearshape"
        case "optional": return "questionmark.square"
        case "counter": return "plus.forwardslash.minus"
        default: return "square"
        }
    }

    private func colorForType(_ type: String) -> Color {
        switch type {
        case "checkbox": return .blue
        case "numeric": return .purple
        case "auto": return .green
        case "optional": return .orange
        case "counter": return .teal
        default: return .gray
        }
    }
}
