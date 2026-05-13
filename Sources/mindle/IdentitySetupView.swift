import SwiftUI

struct IdentitySetupView: View {
    @Environment(\.dismiss) var dismiss
    @State private var alias: String = ""
    @State private var displayName: String = ""
    @State private var selectedColor: String = "#4A90D9"

    let colorPresets = IdentityManager.defaultColors

    var body: some View {
        VStack(spacing: 24) {
            Text("Welcome to MarkCollab")
                .font(.title2).bold()
            Text("Set up your identity for collaboration")
                .foregroundColor(.secondary)

            TextField("Alias (e.g. ash)", text: $alias)
                .textFieldStyle(.roundedBorder)
            TextField("Display Name (e.g. Ashish Naik)", text: $displayName)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 12) {
                ForEach(colorPresets, id: \.self) { color in
                    Circle()
                        .fill(Color(hex: color))
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 2))
                        .onTapGesture { selectedColor = color }
                }
            }

            Button("Get Started") {
                IdentityManager.shared.save(
                    alias: alias.lowercased().trimmingCharacters(in: .whitespaces),
                    displayName: displayName,
                    color: selectedColor
                )
                dismiss()
            }
            .disabled(alias.count < 3 || displayName.isEmpty)
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(width: 420)
    }
}

// MARK: - Color hex extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
