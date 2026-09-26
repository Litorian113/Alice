import SwiftUI

struct DecisionConfirmedView: View {
    let card: DecisionCard
    let option: DecisionOption

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                // Checkmark
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundColor(.bcRiskLow)

                // Decision sent
                VStack(spacing: 6) {
                    Text("Decision sent")
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(.bcMuted)
                        .textCase(.uppercase)

                    Text(option.label)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.bcPrimary)
                }

                // Arrow animation — you → Bob
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill")
                            .foregroundColor(.bcSecondary)
                        Text("You")
                            .foregroundColor(.bcSecondary)
                    }
                    .font(.system(size: 13))

                    Image(systemName: "arrow.down")
                        .foregroundColor(.bcMuted)
                        .font(.system(size: 13))

                    Text(option.label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.bcAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.bcAccent.opacity(0.12))
                        .cornerRadius(6)

                    Image(systemName: "arrow.down")
                        .foregroundColor(.bcMuted)
                        .font(.system(size: 13))

                    HStack(spacing: 6) {
                        Image(systemName: "cpu")
                            .foregroundColor(.bcSecondary)
                        Text("Bob  Working...")
                            .foregroundColor(.bcSecondary)
                    }
                    .font(.system(size: 13))
                }
                .padding(.top, 8)
            }

            Spacer()
        }
    }
}

#Preview {
    DecisionConfirmedView(
        card: MockData.lowRiskDecision,
        option: MockData.lowRiskDecision.options[0]
    )
    .background(Color.bcBackground)
    .preferredColorScheme(.dark)
}
