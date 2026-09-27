import SwiftUI

struct AliceHomeView: View {
    @EnvironmentObject var store: AliceSessionStore

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 22) {
                    if let feedback = store.decisionFeedback {
                        DecisionFeedbackView(phase: feedback.phase)
                            .id(feedback.id)
                            .accessibilityAction(named: Text("Dismiss feedback")) {
                                store.dismissDecisionFeedback(id: feedback.id)
                            }
                    } else {
                        hero
                        if store.isConnected {
                            if let card = store.currentDecision {
                                DecisionCardView(card: card)
                            } else if store.phase == .waiting {
                                VStack(spacing: 14) {
                                    Image(systemName: "sparkles").font(.system(size: 25)).foregroundStyle(Color.aliceRecommended)
                                    Text("Bob's on it.").font(.plex(23, weight: .semibold))
                                    Text(store.latestStatus).font(.plex(15)).foregroundStyle(Color.aliceSecondary)
                                        .multilineTextAlignment(.center)
                                    if !store.notificationsEnabled {
                                        Button("Set up notifications") { store.showsNotifications = true }.frame(minHeight: 44)
                                    }
                                }.padding(26).frame(maxWidth: .infinity).aliceSurface(radius: 30)
                            }
                        } else {
                            disconnected
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 20)
                .frame(minHeight: geometry.size.height, alignment: .center)
                .contentShape(Rectangle())
                .onTapGesture {
                    if let feedback = store.decisionFeedback {
                        store.dismissDecisionFeedback(id: feedback.id)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            ZStack {
                Ellipse()
                    .fill(Color.aliceRecommended.opacity(0.09))
                    .frame(width: 175, height: 94)
                    .blur(radius: 20)
                    .offset(y: 8)
                Image(systemName: "sparkle")
                    .font(.system(size: 18))
                    .foregroundStyle(Color(hex: "B2C9FF"))
                    .offset(x: -82, y: -22)
                Image(systemName: "sparkle")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "C9B7F5"))
                    .offset(x: 82, y: 18)
                AliceMascot(happy: store.phase == .approvedOnce || store.phase == .approvedForTask)
                    .frame(width: 94, height: 112)
                    .rotationEffect(.degrees(store.phase == .needsDecision ? -4 : 0))
            }
            Text(store.currentDecision?.kind == .approval ? "Can Bob run this?" : store.phase.title)
                .font(.plex(28, weight: .semibold, relativeTo: .title))
                .tracking(-0.8)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity)
    }

    private var disconnected: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(store.pairing == nil ? "Bring Bob along." : "Waiting for Bob.").font(.plex(23, weight: .semibold))
            Text(store.pairing == nil ? "Scan Bob's QR code to keep his next decision within reach." : "Your phone is paired. Keep Bob and the relay running; Alice reconnects automatically.")
                .font(.plex(15)).foregroundStyle(Color.aliceSecondary)
            if let error = store.errorMessage { Text(error).font(.plex(13)).foregroundStyle(Color.aliceError) }
            PrimaryButton(title: store.pairing == nil ? "Scan Bob's QR code" : "Connect another session", icon: "qrcode.viewfinder") { store.connectSession() }
        }.padding(24).aliceSurface(radius: 30)
    }
}

/// The mascot sits behind the card edge rather than floating above the result.
struct DecisionFeedbackView: View {
    let phase: AlicePhase

    private var reaction: AliceMascot.Reaction {
        switch phase {
        case .rejected: return .rejected
        case .approvedForTask: return .confident
        case .answered: return .wink
        default: return .delighted
        }
    }

    private var title: String {
        switch phase {
        case .approvedForTask: return "Approved for this task"
        case .rejected: return "Command rejected"
        case .answered: return "Decision received"
        default: return "Approved once"
        }
    }

    private var detail: String {
        switch phase {
        case .approvedForTask: return "Bob received your approval for this task."
        case .rejected: return "Bob received your rejection."
        case .answered: return "Your choice is back with Bob."
        default: return "Bob received your one-time approval."
        }
    }

    var body: some View {
        VStack(spacing: -31) {
            AliceMascot(peeking: true, reaction: reaction)
                .frame(width: 208, height: 175)
                .accessibilityHidden(true)
            VStack(spacing: 12) {
                Image(systemName: phase == .rejected ? "xmark" : "checkmark")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(phase == .rejected ? Color.aliceError : .aliceSuccess)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.plex(23, weight: .semibold, relativeTo: .title2))
                Text(detail)
                    .font(.plex(14)).foregroundStyle(Color.aliceSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 26)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
            .aliceSurface(radius: 30)
        }
        .accessibilityElement(children: .combine)
    }
}
