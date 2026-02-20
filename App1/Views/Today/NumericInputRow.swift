import SwiftUI

struct NumericInputRow: View {
    let title: String
    let subtitle: String?
    let targetMin: Double
    let targetMax: Double
    let unit: String
    @Binding var value: Int?
    var onChanged: () -> Void

    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                TextField("---", text: $textValue)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70)
                    .focused($isFocused)
                    .onChange(of: textValue) { _, newValue in
                        if let intValue = Int(newValue) {
                            value = intValue
                            onChanged()
                        } else if newValue.isEmpty {
                            value = nil
                            onChanged()
                        }
                    }

                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(statusColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? Color.accentColor : statusColor.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 16)
        .onAppear {
            if let value {
                textValue = "\(value)"
            }
        }
    }

    private var statusColor: Color {
        guard let value else { return .secondary }
        let doubleValue = Double(value)
        if doubleValue >= targetMin && doubleValue <= targetMax { return .green }
        let lowerBuffer = targetMin * 0.1
        let upperBuffer = targetMax * 0.1
        if doubleValue >= (targetMin - lowerBuffer) && doubleValue <= (targetMax + upperBuffer) { return .orange }
        return .red
    }
}
