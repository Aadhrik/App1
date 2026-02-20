import SwiftUI
import SwiftData
import Charts

struct BloodworkTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BloodworkEntry.date, order: .reverse) private var entries: [BloodworkEntry]

    @State private var showingAddSheet = false
    @State private var selectedEntry: BloodworkEntry?

    var body: some View {
        NavigationStack {
            List {
                if entries.count >= 2 {
                    Section("Trends") {
                        NavigationLink {
                            BloodworkTrendsView(entries: entries)
                        } label: {
                            Label("View Trends", systemImage: "chart.line.uptrend.xyaxis")
                        }
                    }
                }

                Section("Entries") {
                    ForEach(entries) { entry in
                        NavigationLink {
                            BloodworkDetailView(entry: entry)
                        } label: {
                            BloodworkEntryRow(entry: entry)
                        }
                    }
                    .onDelete(perform: deleteEntries)
                }
            }
            .navigationTitle("Bloodwork Tracker")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .overlay {
                if entries.isEmpty {
                    ContentUnavailableView {
                        Label("No Bloodwork Entries", systemImage: "drop.fill")
                    } description: {
                        Text("Tap the + button to log your bloodwork results.")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                BloodworkFormSheet { newEntry in
                    modelContext.insert(newEntry)
                    try? modelContext.save()
                }
            }
        }
    }

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(entries[index])
        }
        try? modelContext.save()
    }
}

// MARK: - Entry Row

private struct BloodworkEntryRow: View {
    let entry: BloodworkEntry

    private var flaggedCount: Int {
        BloodworkEntry.referenceRanges.reduce(0) { count, pair in
            let status = pair.range.status(for: entry.value(for: pair.keyPath))
            return count + (status == .high || status == .low ? 1 : 0)
        }
    }

    private var filledCount: Int {
        BloodworkEntry.referenceRanges.reduce(0) { count, pair in
            count + (entry.value(for: pair.keyPath) != nil ? 1 : 0)
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.date, style: .date)
                    .font(.body)
                    .fontWeight(.medium)

                Text("\(filledCount) of \(BloodworkEntry.referenceRanges.count) metrics recorded")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if flaggedCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text("\(flaggedCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Detail View

private struct BloodworkDetailView: View {
    let entry: BloodworkEntry

    var body: some View {
        List {
            Section("Date") {
                Text(entry.date, style: .date)
            }

            Section("Lab Results") {
                ForEach(BloodworkEntry.referenceRanges, id: \.keyPath) { pair in
                    let value = entry.value(for: pair.keyPath)
                    let status = pair.range.status(for: value)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pair.range.label)
                                .font(.body)

                            if let min = pair.range.min, let max = pair.range.max {
                                Text("Range: \(formatted(min))-\(formatted(max)) \(pair.range.unit)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if let max = pair.range.max {
                                Text("Range: < \(formatted(max)) \(pair.range.unit)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if let min = pair.range.min {
                                Text("Range: > \(formatted(min)) \(pair.range.unit)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if let value {
                            HStack(spacing: 6) {
                                Text("\(formatted(value)) \(pair.range.unit)")
                                    .font(.body)
                                    .fontWeight(.medium)

                                Circle()
                                    .fill(colorForStatus(status))
                                    .frame(width: 10, height: 10)
                            }
                        } else {
                            Text("--")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            // Blood pressure (separate since it's Int-based)
            Section("Blood Pressure") {
                HStack {
                    Text("Blood Pressure")

                    Spacer()

                    if let sys = entry.systolicBP, let dia = entry.diastolicBP {
                        HStack(spacing: 6) {
                            Text("\(sys)/\(dia) mmHg")
                                .fontWeight(.medium)

                            Circle()
                                .fill(bpColor(systolic: sys, diastolic: dia))
                                .frame(width: 10, height: 10)
                        }
                    } else {
                        Text("--")
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            if let weight = entry.weight {
                Section("Weight") {
                    HStack {
                        Text("Weight")
                        Spacer()
                        Text(String(format: "%.1f lbs", weight))
                            .fontWeight(.medium)
                    }
                }
            }

            if let notes = entry.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                        .font(.body)
                }
            }
        }
        .navigationTitle("Bloodwork Detail")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatted(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private func colorForStatus(_ status: BloodworkEntry.RangeStatus) -> Color {
        switch status {
        case .low: return .blue
        case .normal: return .green
        case .high: return .red
        case .unknown: return .gray
        }
    }

    private func bpColor(systolic: Int, diastolic: Int) -> Color {
        if systolic < 120 && diastolic < 80 { return .green }
        if systolic >= 140 || diastolic >= 90 { return .red }
        return .orange
    }
}

// MARK: - Trends View

private struct BloodworkTrendsView: View {
    let entries: [BloodworkEntry]

    @State private var selectedMetric: String = "hba1c"

    private var sortedEntries: [BloodworkEntry] {
        entries.sorted { $0.date < $1.date }
    }

    private var availableMetrics: [(keyPath: String, range: BloodworkEntry.ReferenceRange)] {
        BloodworkEntry.referenceRanges.filter { pair in
            entries.contains { $0.value(for: pair.keyPath) != nil }
        }
    }

    private var selectedRange: BloodworkEntry.ReferenceRange? {
        availableMetrics.first { $0.keyPath == selectedMetric }?.range
    }

    private var chartData: [(date: Date, value: Double)] {
        sortedEntries.compactMap { entry in
            guard let value = entry.value(for: selectedMetric) else { return nil }
            return (date: entry.date, value: value)
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Metric", selection: $selectedMetric) {
                    ForEach(availableMetrics, id: \.keyPath) { pair in
                        Text(pair.range.label).tag(pair.keyPath)
                    }
                }
                .pickerStyle(.menu)
            }

            if chartData.count >= 2 {
                Section("Chart") {
                    Chart {
                        ForEach(chartData, id: \.date) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Value", point.value)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(.blue)

                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Value", point.value)
                            )
                            .foregroundStyle(pointColor(value: point.value))
                            .symbolSize(40)
                        }

                        // Reference range lines
                        if let range = selectedRange {
                            if let min = range.min {
                                RuleMark(y: .value("Min", min))
                                    .foregroundStyle(.green.opacity(0.5))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                                    .annotation(position: .leading, alignment: .leading) {
                                        Text("Min")
                                            .font(.caption2)
                                            .foregroundStyle(.green)
                                    }
                            }
                            if let max = range.max {
                                RuleMark(y: .value("Max", max))
                                    .foregroundStyle(.red.opacity(0.5))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                                    .annotation(position: .leading, alignment: .leading) {
                                        Text("Max")
                                            .font(.caption2)
                                            .foregroundStyle(.red)
                                    }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .month)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated).year(.twoDigits))
                        }
                    }
                    .frame(height: 220)
                    .padding(.vertical, 8)
                }
            }

            Section("History") {
                ForEach(sortedEntries.reversed()) { entry in
                    if let value = entry.value(for: selectedMetric) {
                        HStack {
                            Text(entry.date, style: .date)
                                .font(.subheadline)

                            Spacer()

                            HStack(spacing: 6) {
                                Text(formattedValue(value))
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                if let range = selectedRange {
                                    Text(range.unit)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Circle()
                                        .fill(statusColor(range.status(for: value)))
                                        .frame(width: 8, height: 8)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Trends")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let first = availableMetrics.first {
                selectedMetric = first.keyPath
            }
        }
    }

    private func pointColor(value: Double) -> Color {
        guard let range = selectedRange else { return .blue }
        return statusColor(range.status(for: value))
    }

    private func statusColor(_ status: BloodworkEntry.RangeStatus) -> Color {
        switch status {
        case .low: return .blue
        case .normal: return .green
        case .high: return .red
        case .unknown: return .gray
        }
    }

    private func formattedValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}

// MARK: - Bloodwork Form Sheet

private struct BloodworkFormSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (BloodworkEntry) -> Void

    @State private var date: Date = Date()
    @State private var hba1c: String = ""
    @State private var fastingGlucose: String = ""
    @State private var totalCholesterol: String = ""
    @State private var ldl: String = ""
    @State private var hdl: String = ""
    @State private var triglycerides: String = ""
    @State private var vitaminD: String = ""
    @State private var vitaminB12: String = ""
    @State private var tsh: String = ""
    @State private var systolicBP: String = ""
    @State private var diastolicBP: String = ""
    @State private var weight: String = ""
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Date") {
                    DatePicker("Test Date", selection: $date, displayedComponents: .date)
                }

                Section {
                    OptionalNumberField(label: "HbA1c (%)", text: $hba1c)
                    OptionalNumberField(label: "Fasting Glucose (mg/dL)", text: $fastingGlucose)
                } header: {
                    Text("Blood Sugar")
                }

                Section {
                    OptionalNumberField(label: "Total Cholesterol (mg/dL)", text: $totalCholesterol)
                    OptionalNumberField(label: "LDL (mg/dL)", text: $ldl)
                    OptionalNumberField(label: "HDL (mg/dL)", text: $hdl)
                    OptionalNumberField(label: "Triglycerides (mg/dL)", text: $triglycerides)
                } header: {
                    Text("Lipid Panel")
                }

                Section {
                    OptionalNumberField(label: "Vitamin D (ng/mL)", text: $vitaminD)
                    OptionalNumberField(label: "Vitamin B12 (pg/mL)", text: $vitaminB12)
                    OptionalNumberField(label: "TSH (mIU/L)", text: $tsh)
                } header: {
                    Text("Vitamins & Thyroid")
                }

                Section {
                    OptionalNumberField(label: "Systolic (mmHg)", text: $systolicBP)
                    OptionalNumberField(label: "Diastolic (mmHg)", text: $diastolicBP)
                } header: {
                    Text("Blood Pressure")
                }

                Section {
                    OptionalNumberField(label: "Weight (lbs)", text: $weight)
                } header: {
                    Text("Weight")
                }

                Section("Notes") {
                    TextField("Additional notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New Bloodwork Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEntry()
                    }
                }
            }
        }
    }

    private func saveEntry() {
        let entry = BloodworkEntry(date: date)
        entry.hba1c = Double(hba1c)
        entry.fastingGlucose = Double(fastingGlucose)
        entry.totalCholesterol = Double(totalCholesterol)
        entry.ldl = Double(ldl)
        entry.hdl = Double(hdl)
        entry.triglycerides = Double(triglycerides)
        entry.vitaminD = Double(vitaminD)
        entry.vitaminB12 = Double(vitaminB12)
        entry.tsh = Double(tsh)
        entry.systolicBP = Int(systolicBP)
        entry.diastolicBP = Int(diastolicBP)
        entry.weight = Double(weight)
        entry.notes = notes.isEmpty ? nil : notes
        onSave(entry)
        dismiss()
    }
}

// MARK: - Optional Number Field

private struct OptionalNumberField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        HStack {
            Text(label)
                .font(.body)
            Spacer()
            TextField("--", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 100)
        }
    }
}
