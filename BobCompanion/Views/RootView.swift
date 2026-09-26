import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: SessionStore

    var body: some View {
        ZStack {
            Color.bcBackground.ignoresSafeArea()

            switch store.appState {
            case .pairing:
                PairingView()
            case .connected(let status):
                ConnectedView(status: status)
            case .decisionPending(let card):
                DecisionCardView(card: card)
            case .decisionExpanded(let card):
                DecisionDetailView(card: card)
            case .decisionConfirmed(let card, let option):
                DecisionConfirmedView(card: card, option: option)
            case .taskCompleted(let message):
                TaskCompletedView(message: message)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: store.appState)
    }
}

#Preview {
    RootView()
        .environmentObject(SessionStore())
}
