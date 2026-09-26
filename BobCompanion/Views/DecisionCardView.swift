import SwiftUI

struct DecisionCardView: View {
    @EnvironmentObject var store: SessionStore
    let card: DecisionCard

    @State private var dragOffset: CGSize = .zero

    var body: some View {
        VStack(spacing: 0) {

            // Header — attention state
            VStack(spacing: 6) {
                Text("BOB NEEDS YOU")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2)
                    .foregroundColor(card.risk.color)
                    .padding(.top, 60)

                Text(card.title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.bcPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                Text(card.context)
                    .font(.system(size: 15))
                    .foregroundColor(.bcSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 28)
                    .padding(.top, 4)

                // Risk badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(card.risk.color)
                        .frame(width: 6, height: 6)
                    Text(card.risk.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(card.risk.color)
                }
                .padding(.top, 8)
            }

            Spacer()

            // Options
            VStack(spacing: 10) {
                Text("Bob recommends")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(.bcMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)

                ForEach(card.options) { option in
                    OptionButton(option: option, risk: card.risk) {
                        submitDecision(option: option)
                    }
                }
            }
            .padding(.bottom, 16)

            // More context link
            Button {
                store.expandDecision(card)
            } label: {
                HStack(spacing: 4) {
                    Text("More context")
                        .font(.system(size: 14))
                        .foregroundColor(.bcMuted)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.bcMuted)
                }
            }
            .padding(.bottom, 40)
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Only allow horizontal drag if exactly 2 options
                    if card.options.count == 2 {
                        dragOffset = value.translation
                    }
                }
                .onEnded { value in
                    handleSwipe(value.translation)
                    withAnimation { dragOffset = .zero }
                }
        )
        .offset(x: dragOffset.width * 0.3)
    }

    private func submitDecision(option: DecisionOption) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        store.submitDecision(card: card, option: option)
    }

    private func handleSwipe(_ translation: CGSize) {
        guard card.options.count == 2 else { return }
        let threshold: CGFloat = 80
        if translation.width > threshold {
            // swipe right → second option (index 1)
            submitDecision(option: card.options[1])
        } else if translation.width < -threshold {
            // swipe left → first option (index 0)
            submitDecision(option: card.options[0])
        }
    }
}

// MARK: - Option Button

struct OptionButton: View {
    let option: DecisionOption
    let risk: DecisionCard.RiskLevel
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if option.recommended {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.bcRecommended)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.label)
                        .font(.system(size: 16, weight: option.recommended ? .bold : .regular))
                        .foregroundColor(option.recommended ? .bcPrimary : .bcSecondary)

                    Text(option.detail)
                        .font(.system(size: 13))
                        .foregroundColor(option.recommended ? .bcSecondary : .bcMuted)
                }

                Spacer()

                if option.recommended {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundColor(.bcMuted)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                option.recommended
                    ? Color.bcSurfaceRaised
                    : Color.bcSurface
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        option.recommended ? Color.bcRecommended.opacity(0.4) : Color.clear,
                        lineWidth: 1
                    )
            )
            .cornerRadius(14)
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    DecisionCardView(card: MockData.lowRiskDecision)
        .environmentObject(SessionStore())
        .background(Color.bcBackground)
        .preferredColorScheme(.dark)
}
