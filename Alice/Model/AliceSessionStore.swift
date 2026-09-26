import Foundation
import Combine

enum AliceTab: String, CaseIterable {
    case usage = "Usage", alice = "Alice", profile = "Profile"
}

enum AlicePhase: Equatable {
    case needsDecision, approvedOnce, approvedForTask, rejected, disconnected

    var title: String {
        switch self {
        case .needsDecision: return "Can Bob run this?"
        case .approvedOnce, .approvedForTask: return "All set."
        case .rejected: return "Got it. Not this one."
        case .disconnected: return "Better together."
        }
    }
}

@MainActor
final class AliceSessionStore: ObservableObject {
    @Published private(set) var selectedTab: AliceTab = .alice
    @Published private(set) var phase: AlicePhase = .needsDecision
    @Published private(set) var isConnected = true
    @Published private(set) var currentDecision: DecisionCard?
    @Published private(set) var lastResponse: DecisionResponse?
    @Published private(set) var lastChoice: DecisionOption?
    @Published var showsVoiceInput = false

    init() { loadNextRequest() }

    func selectTab(_ tab: AliceTab) {
        guard selectedTab != tab else { return }
        selectedTab = tab
        if tab == .alice && isConnected { loadNextRequest() }
    }

    // The UI uses a local request until the relay is connected. No shell command is executed.
    func loadNextRequest() {
        guard isConnected else { return }
        phase = .needsDecision
        currentDecision = AliceFixtures.commandApproval
        lastResponse = nil
        lastChoice = nil
    }

    func submitDecision(card: DecisionCard, option: DecisionOption) {
        guard isConnected, currentDecision?.id == card.id,
              card.options.contains(option), let choice = option.approvalChoice else { return }
        lastResponse = DecisionResponse(id: card.id, optionId: option.id)
        lastChoice = option
        currentDecision = nil
        switch choice {
        case .once: phase = .approvedOnce
        case .task: phase = .approvedForTask
        case .reject: phase = .rejected
        }
    }

    func openVoiceInput() {
        guard isConnected else { return }
        showsVoiceInput = true
    }

    func disconnect() {
        isConnected = false
        phase = .disconnected
        currentDecision = nil
        lastResponse = nil
        lastChoice = nil
        showsVoiceInput = false
    }

    func connectSession() {
        isConnected = true
        selectedTab = .alice
        loadNextRequest()
    }
}
