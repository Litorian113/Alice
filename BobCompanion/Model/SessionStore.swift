import Foundation
import Combine

// MARK: - App State Machine

enum AppState: Equatable {
    case pairing
    case connected(BobStatus)
    case decisionPending(DecisionCard)
    case decisionExpanded(DecisionCard)
    case decisionConfirmed(DecisionCard, DecisionOption)
    case taskCompleted(String)

    static func == (lhs: AppState, rhs: AppState) -> Bool {
        switch (lhs, rhs) {
        case (.pairing, .pairing): return true
        case (.connected(let a), .connected(let b)): return a == b
        case (.decisionPending(let a), .decisionPending(let b)): return a == b
        case (.decisionExpanded(let a), .decisionExpanded(let b)): return a == b
        case (.taskCompleted(let a), .taskCompleted(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - Bob Working Status

struct BobStatus: Equatable {
    let currentActivity: String
    let startedAt: Date
}

// MARK: - Session Store

@MainActor
final class SessionStore: ObservableObject {
    @Published var appState: AppState = .pairing
    @Published var activityLog: [ActivityItem] = []
    @Published var pendingInstruction: String = ""

    // MARK: - Mock transitions (used until backend is wired)

    func simulatePaired() {
        appState = .connected(BobStatus(
            currentActivity: "Refactoring authentication",
            startedAt: Date().addingTimeInterval(-360)
        ))
        addActivity("Session started", kind: .notification)
        addActivity("Started refactor", kind: .bobAction)
        addActivity("Updated auth service", kind: .bobAction)
        addActivity("Running tests", kind: .bobAction)
    }

    func simulateDecisionArrived(_ card: DecisionCard) {
        appState = .decisionPending(card)
        addActivity("Bob needs you: \(card.title)", kind: .notification)
    }

    func expandDecision(_ card: DecisionCard) {
        appState = .decisionExpanded(card)
    }

    func collapseDecision(_ card: DecisionCard) {
        appState = .decisionPending(card)
    }

    func submitDecision(card: DecisionCard, option: DecisionOption, freeText: String? = nil) {
        appState = .decisionConfirmed(card, option)
        addActivity("You chose: \(option.label)", kind: .userDecision)

        // Simulate Bob resuming after short delay, then back to connected
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self else { return }
            self.appState = .connected(BobStatus(
                currentActivity: "Fixing tests",
                startedAt: Date()
            ))
            self.addActivity("Bob resumed: \(option.label)", kind: .bobAction)
        }
    }

    func simulateTaskCompleted(message: String) {
        appState = .taskCompleted(message)
        addActivity(message, kind: .notification)
    }

    func disconnect() {
        appState = .pairing
        activityLog = []
    }

    private func addActivity(_ description: String, kind: ActivityItem.Kind) {
        activityLog.append(ActivityItem(description: description, kind: kind))
    }
}
