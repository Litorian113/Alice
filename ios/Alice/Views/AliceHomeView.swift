import SwiftUI

struct AliceHomeView: View {
    @EnvironmentObject var store: AliceSessionStore

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                hero
                if store.isConnected {
                    if let card = store.currentDecision {
                        DecisionCardView(card: card)
                    } else {
                        outcome
                    }
                } else {
                    disconnected
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
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
            Text(store.phase.title)
                .font(.plex(28, weight: .semibold, relativeTo: .title))
                .tracking(-0.8)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity)
    }

    private var outcome: some View {
        VStack(spacing: 18) {
            Image(systemName: store.phase == .rejected ? "xmark" : "checkmark")
                .font(.system(size: 27, weight: .medium))
                .foregroundStyle(store.phase == .rejected ? Color.aliceError : .aliceSuccess)
                .frame(width: 64, height: 64)
                .background(store.phase == .rejected ? Color.aliceError.opacity(0.07) : Color.aliceSuccess.opacity(0.08), in: Circle())
            VStack(spacing: 8) {
                Text(outcomeTitle).font(.plex(22, weight: .semibold))
                Text(outcomeDetail)
                    .font(.plex(14)).foregroundStyle(Color.aliceSecondary)
                    .multilineTextAlignment(.center)
            }
            Button { store.loadNextRequest() } label: {
                Label("Next request", systemImage: "arrow.right")
                    .font(.plex(14, weight: .medium))
                    .frame(minHeight: 44)
            }
            .accessibilityIdentifier("approval.next")
        }
        .padding(26)
        .frame(maxWidth: .infinity)
        .aliceSurface(radius: 30)
    }

    private var outcomeTitle: String {
        switch store.phase {
        case .approvedForTask: return "Approved for this task"
        case .rejected: return "Command rejected"
        default: return "Approved once"
        }
    }

    private var outcomeDetail: String {
        switch store.phase {
        case .approvedForTask: return "Bob can use this command again during the current task."
        case .rejected: return "This command isn't allowed. Bob will need another approach."
        default: return "Bob can run this command once. The next request is yours to decide."
        }
    }

    private var disconnected: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Bring Bob along.").font(.plex(23, weight: .semibold))
            Text("Connect a session to keep his next decision within reach.")
                .font(.plex(15)).foregroundStyle(Color.aliceSecondary)
            PrimaryButton(title: "Connect to Bob") { store.connectSession() }
        }.padding(24).aliceSurface(radius: 30)
    }
}
