import SwiftUI

struct DecisionCardView: View {
    @EnvironmentObject var store: SessionStore
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    let card: DecisionCard
    @State private var showsDetails = false
    @State private var confirmationOption: DecisionOption?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left.and.text.bubble.right")
                    Text("BOB NEEDS YOU").tracking(1.3)
                }
                .font(.plex(10, weight: .semibold, relativeTo: .caption))
                .foregroundStyle(Color.bcAccent)
                Spacer()
                Text(card.risk.label)
                    .font(.plex(10, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(card.risk.color)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(card.risk.color.opacity(0.08), in: Capsule())
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(card.title).font(.plex(23, weight: .semibold, relativeTo: .title2)).tracking(-0.6)
                Text(card.context).font(.plex(13)).foregroundStyle(Color.bcSecondary).lineSpacing(2)
            }
            VStack(spacing: 8) {
                ForEach(card.options) { option in
                    OptionButton(option: option) {
                        if card.risk == .high { confirmationOption = option }
                        else { submit(option) }
                    }
                }
            }
            Button { showsDetails = true } label: {
                HStack(spacing: 5) {
                    Text("A little more context")
                    Image(systemName: "arrow.up.right").font(.system(size: 10))
                }
                .font(.plex(12)).foregroundStyle(Color.bcSecondary)
                .frame(maxWidth: .infinity).frame(minHeight: 30)
            }
            .accessibilityIdentifier("decision.context")
        }
        .padding(18)
        .companionSurface()
        .sheet(isPresented: $showsDetails) {
            DecisionDetailView(card: card)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog("Confirm this high-risk decision", isPresented: Binding(
            get: { confirmationOption != nil },
            set: { if !$0 { confirmationOption = nil } }
        ), titleVisibility: .visible) {
            if let option = confirmationOption {
                Button(option.label, role: .destructive) { submit(option) }
            }
            Button("Cancel", role: .cancel) { confirmationOption = nil }
        } message: { Text(card.context) }
    }

    private func submit(_ option: DecisionOption) {
        if hapticsEnabled { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        store.submitDecision(card: card, option: option)
    }
}

struct OptionButton: View {
    let option: DecisionOption
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(option.label).font(.plex(15, weight: .medium))
                        if option.recommended {
                            Image(systemName: "sparkles").font(.system(size: 11))
                            Text("BOB'S PICK").font(.plex(8, weight: .semibold, relativeTo: .caption2)).tracking(0.8)
                        }
                    }
                    Text(option.detail)
                        .font(.plex(11))
                        .foregroundStyle(option.recommended ? Color.white.opacity(0.85) : .bcSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: option.recommended ? "arrow.right" : "chevron.right")
                    .font(.system(size: option.recommended ? 16 : 11, weight: .medium))
            }
            .foregroundStyle(option.recommended ? .white : Color.bcPrimary)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 55, alignment: .leading)
            .background(option.recommended ? Color.bcAccent : .bcBackground, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("decision.\(option.id)")
        .accessibilityLabel("\(option.label). \(option.detail)\(option.recommended ? ". Bob recommends this option." : "")")
    }
}
