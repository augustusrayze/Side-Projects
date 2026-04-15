import SwiftUI

/// Reusable full-screen date picker overlay used on both the Today
/// and Daily Prayer screens.
struct DatePickerOverlay: View {
    @Binding var pendingDate: Date
    /// Label for the confirm button (e.g. "Open Saint" or "Open Prayer").
    let confirmLabel: String
    let onClose: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.12)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack {
                VStack(spacing: 20) {
                    HStack {
                        Text("Select a Date")
                            .font(.saintHeading)
                            .foregroundStyle(Color.inkBrown)

                        Spacer()

                        Button("Close", action: onClose)
                            .font(.saintBody)
                            .foregroundStyle(Color.inkBrown.opacity(0.8))
                    }

                    DatePicker(
                        "Choose a Date",
                        selection: $pendingDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)

                    Button(action: onConfirm) {
                        Text(confirmLabel)
                            .font(.saintBody)
                            .foregroundStyle(Color.parchment)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.ancientGold)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .background(Color.parchment)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.ancientGold.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: Color.inkBrown.opacity(0.18), radius: 16, x: 0, y: 8)
                .padding(.horizontal, 20)
                .padding(.top, 110)

                Spacer()
            }
        }
    }
}
