import Foundation
import Combine

enum CompanionTab: String, CaseIterable {
    case usage = "Usage", alice = "Alice", profile = "Profile"
}

enum CompanionPhase: Equatable {
    case needsDecision, working, completed, reverted, paused, disconnected

    var title: String {
        switch self {
        case .needsDecision: return "A little help, Franz?"
        case .working: return "On it. You've got this."
        case .completed: return "All green. All done."
        case .reverted: return "Back on familiar ground."
        case .paused: return "Take your time, Franz."
        case .disconnected: return "Better together."
        }
    }

    var subtitle: String {
        switch self {
        case .needsDecision: return "One quick decision. Then I'll take it from here."
        case .working: return "Bob handles the code. I'll keep you in the loop."
        case .completed: return "A little teamwork goes a long way."
        case .reverted: return "Your last green state is restored."
        case .paused: return "I'll be right here when you're ready."
        case .disconnected: return "Your companion for Bob, wherever you are."
        }
    }

    var status: String {
        switch self {
        case .needsDecision: return "Needs your input"
        case .working: return "Working on it"
        case .completed: return "Task complete"
        case .reverted: return "Refactor reverted"
        case .paused: return "Session paused"
        case .disconnected: return "Disconnected"
        }
    }
}

struct ConversationMessage: Identifiable {
    enum Sender { case alice, you }
    let id = UUID()
    let sender: Sender
    let text: String
}

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var selectedTab: CompanionTab = .alice
    @Published private(set) var phase: CompanionPhase = .needsDecision
    @Published private(set) var isDemoConnected = true
    @Published private(set) var messages: [ConversationMessage] = []
    @Published private(set) var currentDecision: DecisionCard?
    @Published private(set) var lastResponse: DecisionResponse?
    @Published private(set) var instructions: [String] = []
    @Published var showsInstruction = false
    @Published var prefersVoice = false
    private var demoTask: Task<Void, Never>?

    init() { restartDemo() }

    func selectTab(_ tab: CompanionTab) {
        guard selectedTab != tab else { return }
        selectedTab = tab
        if tab == .alice && isDemoConnected { restartDemo() }
    }

    func restartDemo() {
        demoTask?.cancel()
        guard isDemoConnected else { return }
        phase = .needsDecision
        currentDecision = MockData.lowRiskDecision
        lastResponse = nil
        instructions = []
        messages = [
            ConversationMessage(sender: .you, text: "Refactor the auth module and run the tests."),
            ConversationMessage(sender: .alice, text: "Bob's finished the refactor! His test run caught something that needs your call.")
        ]
    }

    func submitDecision(card: DecisionCard, option: DecisionOption, freeText: String? = nil) {
        guard isDemoConnected, currentDecision?.id == card.id,
              card.options.contains(option) else { return }
        demoTask?.cancel()
        lastResponse = DecisionResponse(id: card.id, optionId: option.id, text: freeText)
        currentDecision = nil
        messages.append(ConversationMessage(sender: .you, text: option.label))
        if let freeText, !freeText.isEmpty {
            messages.append(ConversationMessage(sender: .you, text: freeText))
        }
        if option.id == "c" {
            phase = .paused
            messages.append(ConversationMessage(sender: .alice, text: "Bob's paused. I'll be here when you're ready to pick things up."))
            return
        }
        phase = .working
        let isRevert = option.id == "b"
        messages.append(ConversationMessage(sender: .alice, text: isRevert
            ? "Got it. I've asked Bob to restore the previous version and check the tests."
            : "Good call. I've asked Bob to update the outdated mocks and rerun the suite."))
        demoTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(2.2)) }
            catch { return }
            guard let self, !Task.isCancelled, self.isDemoConnected else { return }
            self.phase = isRevert ? .reverted : .completed
            self.messages.append(ConversationMessage(sender: .alice, text: isRevert
                ? "Bob's restored the previous version. All 48 tests pass again."
                : "Good news from Bob: all 48 tests passed. Refactor complete. Go enjoy your day!"))
        }
    }

    func openInstruction(voice: Bool) {
        guard isDemoConnected else { return }
        prefersVoice = voice
        showsInstruction = true
    }

    func sendInstruction(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isDemoConnected, !trimmed.isEmpty else { return }
        instructions.append(trimmed)
        messages.append(ConversationMessage(sender: .you, text: trimmed))
        messages.append(ConversationMessage(sender: .alice, text: "Added to this demo session. When your IDE is connected, Bob will pick up your instruction there."))
        showsInstruction = false
    }

    func disconnect() {
        demoTask?.cancel()
        isDemoConnected = false
        phase = .disconnected
        currentDecision = nil
        messages = []
        instructions = []
        lastResponse = nil
        showsInstruction = false
    }

    func connectDemo() {
        isDemoConnected = true
        selectedTab = .alice
        restartDemo()
    }
}
