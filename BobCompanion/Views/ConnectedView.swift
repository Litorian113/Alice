import SwiftUI

struct ConnectedView: View {
    @EnvironmentObject var store: SessionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 18) {
                    AppHeader()
                    hero
                    if store.isDemoConnected {
                        sessionLabel
                        conversation
                        if let card = store.currentDecision {
                            DecisionCardView(card: card)
                        } else {
                            outcome
                        }
                        Button { store.openInstruction(voice: false) } label: {
                            HStack {
                                Image(systemName: "text.bubble")
                                Text("Or type an instruction…")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.plex(14))
                            .foregroundStyle(Color.bcSecondary)
                            .padding(17)
                            .companionSurface(radius: 18)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("instruction.open")
                    } else {
                        disconnected
                    }
                    Color.clear.frame(height: 8).id("conversationBottom")
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
            .onChange(of: store.messages.count) { old, new in
                guard new > old else { return }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                    proxy.scrollTo("conversationBottom", anchor: .bottom)
                }
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 6) {
            ZStack {
                Ellipse()
                    .fill(Color.bcAccent.opacity(0.07))
                    .frame(width: 167, height: 92)
                    .blur(radius: 16)
                    .offset(y: 6)
                Image(systemName: "sparkle")
                    .font(.system(size: 17))
                    .foregroundStyle(Color(hex: "B2C9FF"))
                    .offset(x: -81, y: -14)
                Image(systemName: "sparkle")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "C9B7F5"))
                    .offset(x: 76, y: 19)
                AliceMascot(happy: store.phase == .completed || store.phase == .reverted)
                    .frame(width: 106, height: 126)
                    .rotationEffect(.degrees(store.phase == .needsDecision ? -4 : 0))
            }
            Text(store.phase.title)
                .font(.plex(27, weight: .semibold, relativeTo: .title))
                .tracking(-0.8)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(store.phase.subtitle)
                .font(.plex(12))
                .foregroundStyle(Color.bcSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, -8)
        .padding(.bottom, 5)
    }

    private var sessionLabel: some View {
        HStack(spacing: 10) {
            Image(systemName: "laptopcomputer").font(.system(size: 18)).foregroundStyle(Color.bcSecondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("bob-companion").font(.plex(12, weight: .medium))
                Text("Auth refactor · demo session").font(.plex(10, relativeTo: .caption)).foregroundStyle(Color.bcSecondary)
            }
            Spacer(minLength: 4)
            Circle().fill(store.phase == .needsDecision ? Color.bcRiskMedium : .bcSuccess).frame(width: 6, height: 6)
            Text(store.phase.status)
                .font(.plex(10, weight: .medium, relativeTo: .caption))
                .foregroundStyle(Color.bcSecondary)
        }
        .padding(12)
        .background(Color.bcSurfaceRaised.opacity(0.8), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    private var conversation: some View {
        VStack(spacing: 12) {
            // The decision card is the first update Alice brings from Bob. Show the whole thread after a response.
            ForEach(store.currentDecision != nil ? Array(store.messages.filter { $0.sender == .you }) : store.messages) { message in
                ConversationBubble(message: message)
            }
        }
    }

    @ViewBuilder private var outcome: some View {
        if store.phase == .working {
            HStack(spacing: 12) {
                ProgressView().tint(.bcAccent)
                Text("Bob is working on your decision…").font(.plex(13))
                Spacer()
            }.padding(18).companionSurface(radius: 18)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: store.phase == .paused ? "pause.circle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(store.phase == .paused ? Color.bcRiskMedium : .bcSuccess)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.phase == .paused ? "Paused until you're back" : "48 / 48 tests passed")
                            .font(.plex(17, weight: .semibold))
                        Text(store.phase == .paused ? "No more changes will be made." : (store.phase == .reverted ? "Previous version restored" : "Authentication refactor complete"))
                            .font(.plex(12)).foregroundStyle(Color.bcSecondary)
                    }
                }
                Button { store.restartDemo() } label: {
                    Label("Replay demo", systemImage: "arrow.counterclockwise")
                        .font(.plex(13, weight: .medium))
                }
                .accessibilityIdentifier("demo.replay")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20).companionSurface()
        }
    }

    private var disconnected: some View {
        VStack(alignment: .leading, spacing: 16) {
            Eyebrow(text: "Let's reconnect")
            Text("Your desk can wait.").font(.plex(23, weight: .semibold))
            Text("Meet Alice, your companion for Bob. Make a decision, pass on an instruction, and let Bob get back to work.")
                .font(.plex(15)).foregroundStyle(Color.bcSecondary)
            PrimaryButton(title: "Start demo session") { store.connectDemo() }
            Text("IDE pairing will arrive with the backend connection.")
                .font(.plex(12)).foregroundStyle(Color.bcSecondary)
        }.padding(22).companionSurface()
    }
}

struct ConversationBubble: View {
    let message: ConversationMessage
    private var isYou: Bool { message.sender == .you }
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isYou { Spacer(minLength: 36) }
            else {
                AliceMascot(faceOnly: true, animated: false)
                    .frame(width: 27, height: 24)
                    .padding(.bottom, 4)
            }
            Text(message.text)
                .font(.plex(13))
                .foregroundStyle(isYou ? Color.bcPrimary : .bcSecondary)
                .padding(.horizontal, 15).padding(.vertical, 11)
                .background(isYou ? Color(hex: "E7EDFF") : .white,
                            in: UnevenRoundedRectangle(topLeadingRadius: 17, bottomLeadingRadius: isYou ? 17 : 4,
                                                       bottomTrailingRadius: isYou ? 4 : 17, topTrailingRadius: 17))
            if !isYou { Spacer(minLength: 22) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(isYou ? "You" : "Alice"): \(message.text)")
    }
}
