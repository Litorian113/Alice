import SwiftUI

struct DecisionCardView: View {
    @EnvironmentObject var store: AliceSessionStore
    @Environment(\.dynamicTypeSize) private var typeSize
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    let card: DecisionCard
    @State private var showsDetails = false
    @State private var confirmationOption: DecisionOption?

    private var alternatives: [DecisionOption] {
        card.options.filter { $0.approvalChoice != .once }
    }

    var body: some View {
        VStack(spacing: 14) {
            requestBubble
            VStack(spacing: 12) {
              if card.kind == .approval {
                if let once = card.options.first(where: { $0.approvalChoice == .once }) {
                    ApprovalBubble(option: once, prominent: true) { choose(once) }
                }
                if typeSize.isAccessibilitySize {
                    VStack(spacing: 12) { alternativeBubbles }
                } else {
                    HStack(alignment: .top, spacing: 12) { alternativeBubbles }
                }
              } else {
                ForEach(card.options) { option in
                    Button { choose(option) } label: {
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(option.label).font(.plex(18, weight: .semibold))
                                if !option.detail.isEmpty { Text(option.detail).font(.plex(13)) }
                            }
                            Spacer(minLength: 4)
                            Image(systemName: option.recommended ? "sparkles" : "arrow.right")
                        }
                        .foregroundStyle(option.recommended ? .white : Color.alicePrimary)
                        .padding(20).frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                        .background(option.recommended ? Color.aliceAccent : .white,
                                    in: RoundedRectangle(cornerRadius: 24))
                    }.buttonStyle(ApprovalPressStyle())
                    .accessibilityHint(option.recommended ? "Bob's recommendation" : "")
                }
              }
            }
            .disabled(!store.isConnected || store.hasPendingResponse)
            if store.isSending {
                ProgressView("Waiting for Bob…").font(.plex(14))
            }
            if let error = store.errorMessage {
                Text(error).font(.plex(13)).foregroundStyle(Color.aliceError).multilineTextAlignment(.center)
            }
            if store.hasPendingResponse && !store.isSending {
                Button("Retry this decision") { store.retryDecision() }
                    .font(.plex(15, weight: .medium)).frame(minHeight: 44).disabled(!store.isConnected)
            }
        }
        .sheet(isPresented: $showsDetails) {
            DecisionDetailView(card: card)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog("Allow this action?", isPresented: Binding(
            get: { confirmationOption != nil },
            set: { if !$0 { confirmationOption = nil } }
        ), titleVisibility: .visible) {
            if let option = confirmationOption {
                Button(option.label, role: .destructive) { submit(option) }
            }
            Button("Cancel", role: .cancel) { confirmationOption = nil }
        } message: { Text(card.context) }
    }

    private var requestBubble: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Text(card.title)
                    .font(.plex(22, weight: .semibold, relativeTo: .title2)).tracking(-0.5)
                Spacer(minLength: 0)
                Button { showsDetails = true } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.aliceSecondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("About this request")
                .accessibilityIdentifier("decision.context")
            }
            if let command = card.command {
                CommandSnippet(command: command)
            }
            Text(card.context)
                .font(.plex(14)).foregroundStyle(Color.aliceSecondary)
                .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 30))
        .overlay(alignment: .top) {
            RequestPointer().fill(.white).frame(width: 25, height: 12).offset(y: -10)
        }
    }

    private var alternativeBubbles: some View {
        ForEach(alternatives) { option in
            ApprovalBubble(option: option) { choose(option) }
        }
    }

    private func choose(_ option: DecisionOption) {
        if card.risk == .high && option.approvalChoice != .reject {
            confirmationOption = option
        } else { submit(option) }
    }

    private func submit(_ option: DecisionOption) {
        if hapticsEnabled { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
        store.submitDecision(card: card, option: option)
    }
}

private struct RequestPointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: 0), control: CGPoint(x: rect.midX - 3, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.midX + 3, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct CommandSnippet: View {
    let command: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("›").foregroundStyle(Color(hex: "9CB6FF"))
            Text(command)
                .foregroundStyle(Color(hex: "E7ECFC"))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(.footnote, design: .monospaced))
        .padding(16)
        .background(Color.alicePrimary, in: RoundedRectangle(cornerRadius: 17))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Command: \(command)")
    }
}

private struct ApprovalBubble: View {
    let option: DecisionOption
    var prominent = false
    var action: () -> Void
    private var rejected: Bool { option.approvalChoice == .reject }
    private var tint: Color { prominent ? .white : (rejected ? .aliceError : .aliceRecommended) }
    private var fill: Color { prominent ? .aliceAccent : (rejected ? Color(hex: "FBECEE") : Color(hex: "EDE8FC")) }
    private var icon: String { prominent ? "checkmark" : (rejected ? "xmark" : "checkmark.seal") }

    var body: some View {
        Button(action: action) {
            Group {
                if prominent {
                    HStack(spacing: 15) {
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.16), in: Circle())
                        labels
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.right").font(.system(size: 18))
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: icon).font(.system(size: 21, weight: .medium))
                        labels
                    }
                    .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
                }
            }
            .foregroundStyle(tint)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: UnevenRoundedRectangle(
                topLeadingRadius: 28, bottomLeadingRadius: rejected ? 28 : 10,
                bottomTrailingRadius: rejected ? 10 : 28, topTrailingRadius: 28))
        }
        .buttonStyle(ApprovalPressStyle())
        .accessibilityIdentifier("decision.\(option.id)")
        .accessibilityLabel("\(option.label). \(option.detail)")
    }

    private var labels: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(option.label).font(.plex(prominent ? 19 : 16, weight: .semibold))
            Text(option.detail)
                .font(.plex(12)).opacity(prominent ? 0.85 : 0.9)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ApprovalPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
