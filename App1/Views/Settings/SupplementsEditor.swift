import SwiftUI
import SwiftData

struct SupplementsEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Supplement.sortOrder) private var supplements: [Supplement]

    @State private var showingAddSheet = false
    @State private var supplementToEdit: Supplement?

    var body: some View {
        NavigationStack {
            List {
                ForEach(supplements) { supplement in
                    SupplementRow(supplement: supplement)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            supplementToEdit = supplement
                        }
                }
                .onDelete(perform: deleteSupplements)
                .onMove(perform: moveSupplements)
            }
            .navigationTitle("Supplements")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
            .overlay {
                if supplements.isEmpty {
                    ContentUnavailableView {
                        Label("No Supplements", systemImage: "pill")
                    } description: {
                        Text("Tap the + button to add a supplement.")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                SupplementFormSheet(supplement: nil) { name, dosage, timing, notes in
                    let maxOrder = supplements.map(\.sortOrder).max() ?? -1
                    let newSupplement = Supplement(
                        name: name,
                        dosage: dosage,
                        timing: timing,
                        notes: notes.isEmpty ? nil : notes,
                        sortOrder: maxOrder + 1
                    )
                    modelContext.insert(newSupplement)
                    try? modelContext.save()
                }
            }
            .sheet(item: $supplementToEdit) { supplement in
                SupplementFormSheet(supplement: supplement) { name, dosage, timing, notes in
                    supplement.name = name
                    supplement.dosage = dosage
                    supplement.timing = timing
                    supplement.notes = notes.isEmpty ? nil : notes
                    try? modelContext.save()
                }
            }
        }
    }

    private func deleteSupplements(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(supplements[index])
        }
        try? modelContext.save()
    }

    private func moveSupplements(from source: IndexSet, to destination: Int) {
        var ordered = supplements
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, supplement) in ordered.enumerated() {
            supplement.sortOrder = index
        }
        try? modelContext.save()
    }
}

// MARK: - Supplement Row

private struct SupplementRow: View {
    let supplement: Supplement

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: supplement.isActive ? "pill.fill" : "pill")
                .foregroundStyle(supplement.isActive ? .blue : .gray)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(supplement.name)
                    .font(.body)
                    .fontWeight(.medium)

                Text(supplement.dosage)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let notes = supplement.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Text(supplement.timing.capitalized)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(timingColor(supplement.timing).opacity(0.15))
                .foregroundStyle(timingColor(supplement.timing))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }

    private func timingColor(_ timing: String) -> Color {
        switch timing {
        case "morning": return .orange
        case "evening": return .indigo
        default: return .gray
        }
    }
}

// MARK: - Supplement Form Sheet

private struct SupplementFormSheet: View {
    @Environment(\.dismiss) private var dismiss

    let supplement: Supplement?
    let onSave: (String, String, String, String) -> Void

    @State private var name: String = ""
    @State private var dosage: String = ""
    @State private var timing: String = "morning"
    @State private var notes: String = ""
    @State private var isActive: Bool = true

    private let timingOptions = ["morning", "evening", "anytime"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    TextField("Dosage", text: $dosage)
                }

                Section("Timing") {
                    Picker("When to Take", selection: $timing) {
                        ForEach(timingOptions, id: \.self) { option in
                            Text(option.capitalized).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Notes") {
                    TextField("Additional notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if supplement != nil {
                    Section {
                        Toggle("Active", isOn: $isActive)
                    }
                }
            }
            .navigationTitle(supplement == nil ? "Add Supplement" : "Edit Supplement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let supplement {
                            supplement.isActive = isActive
                        }
                        onSave(name, dosage, timing, notes)
                        dismiss()
                    }
                    .disabled(name.isEmpty || dosage.isEmpty)
                }
            }
            .onAppear {
                if let supplement {
                    name = supplement.name
                    dosage = supplement.dosage
                    timing = supplement.timing
                    notes = supplement.notes ?? ""
                    isActive = supplement.isActive
                }
            }
        }
    }
}
