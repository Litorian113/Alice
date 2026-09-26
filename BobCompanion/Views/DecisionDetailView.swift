import SwiftUI

// MARK: - Progressive disclosure — expanded decision with full context

struct DecisionDetailView: View {
    @EnvironmentObject var store: SessionStore
    let card: DecisionCard

    var body: some View {
        VStack(spacing: 0) {

            // Navigation
            HStack {
                Button {
                    store.collapseDecision(card)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.system(size: 15))
                    .foregroundColor(.bcSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 60)
            .padding(.bottom, 24)

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {

                    // Title
                    Text(card.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.bcPrimary)

                    // What happened
                    ContextSection(
                        heading: "WHAT HAPPENED",
                        content: card.context
                    )

                    // Bob's recommendation
                    if let recommended = card.options.first(where: { $0.recommended }) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("BOB'S RECOMMENDATION")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(1.5)
                                .foregroundColor(.bcMuted)

                            HStack(spacing: 10) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.bcRecommended)
                                    .font(.system(size: 14))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(recommended.label)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.bcPrimary)
                                    Text(recommended.detail)
                                        .font(.system(size: 13))
                                        .foregroundColor(.bcSecondary)
                                }
                            }
                            .padding(16)
                            .background(Color.bcSurfaceRaised)
                            .cornerRadius(12)
                        }
                    }

                    // Risk
                    HStack(spacing: 8) {
                        Circle()
                            .fill(card.risk.color)
                            .frame(width: 8, height: 8)
                        Text(card.risk.label.uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.5)
                            .foregroundColor(card.risk.color)
                    }

                    Divider()
                        .background(Color.bcSurface)

                    // All options
                    VStack(spacing: 10) {
                        ForEach(card.options) { option in
                            OptionButton(option: option, risk: card.risk) {
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                store.submitDecision(card: card, option: option)
                            }
                        }
                    }
                    .padding(.horizontal, -24) // OptionButton adds its own padding
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
    }
}

struct ContextSection: View {
    let heading: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(heading)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.5)
                .foregroundColor(.bcMuted)
            Text(content)
                .font(.system(size: 15))
                .foregroundColor(.bcSecondary)
                .lineSpacing(4)
        }
    }
}

#Preview {
    DecisionDetailView(card: MockData.highRiskDecision)
        .environmentObject(SessionStore())
        .background(Color.bcBackground)
        .preferredColorScheme(.dark)
}
