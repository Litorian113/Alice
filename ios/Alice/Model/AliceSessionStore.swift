import Foundation
import Combine

enum AliceTab: String, CaseIterable {
    case usage = "Usage", alice = "Alice", profile = "Profile"
}

enum AlicePhase: Equatable {
    case needsDecision, approvedOnce, approvedForTask, rejected, answered, waiting, disconnected
    var title: String {
        switch self {
        case .needsDecision: return "Bob needs your call."
        case .approvedOnce, .approvedForTask, .answered: return "All set."
        case .rejected: return "Got it. Not this one."
        case .waiting: return "You're in the loop."
        case .disconnected: return "Better together."
        }
    }
}

@MainActor
final class AliceSessionStore: ObservableObject {
    @Published private(set) var selectedTab: AliceTab = .alice
    @Published private(set) var phase: AlicePhase = .disconnected
    @Published private(set) var isConnected = false
    @Published private(set) var currentDecision: DecisionCard?
    @Published private(set) var lastResponse: DecisionResponse?
    @Published private(set) var lastChoice: DecisionOption?
    @Published private(set) var pairing: Pairing?
    @Published private(set) var isSending = false
    @Published private(set) var connectionText = "Not connected"
    @Published private(set) var latestStatus = "Bob's next question will appear here."
    @Published var errorMessage: String?
    @Published var showsVoiceInput = false
    @Published var showsPairing = false
    @Published var showsNotifications = false
    @Published var pairingCandidate: Pairing?
    @Published var notificationsEnabled = UserDefaults.standard.bool(forKey: "ntfyEnabled")

    private let relay = RelayClient()
    private lazy var voiceBridge = RelayVoiceBridge(relay: relay)
    private var voiceAvailable = false
    private var cards: [DecisionCard] = []
    private var sendingTimeout: Task<Void, Never>?
    private var expiryTimer: Task<Void, Never>?
    private var active = false
    var hasPendingResponse: Bool { lastResponse?.id == currentDecision?.id && lastResponse != nil }

    init() {
        pairing = PairingStorage.load()
        relay.onState = { [weak self] in self?.connectionChanged($0) }
        relay.onMessage = { [weak self] in self?.receive($0, data: $1) }
    }

    func resume() {
        guard !active else { return }
        active = true
        startConnection()
        expiryTimer = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                self?.expireCards()
            }
        }
    }

    func pause() {
        active = false
        relay.disconnect()
        expiryTimer?.cancel()
        connectionChanged(.offline)
    }

    private func startConnection() {
        guard active, let pairing else { return }
        relay.connect(pairing, pushTopic: notificationsEnabled ? pairing.pushTopic : nil,
                      pushClick: notificationsEnabled ? "bobcompanion://open" : nil)
    }

    func handleURL(_ url: URL) {
        if url.scheme == "bobcompanion", url.host == "open" {
            selectedTab = .alice
            return
        }
        do {
            pairingCandidate = try Pairing.parse(url)
            errorMessage = nil
            showsPairing = true
        } catch {
            errorMessage = error.localizedDescription
            showsPairing = true
        }
    }

    func confirmPairing() {
        guard let candidate = pairingCandidate else { return }
        do {
            try PairingStorage.save(candidate)
            relay.disconnect()
            resetRequests()
            voiceBridge.reset()
            pairing = candidate
            pairingCandidate = nil
            errorMessage = nil
            showsPairing = false
            selectedTab = .alice
            phase = .waiting
            startConnection()
        } catch { errorMessage = PairingError.storage.localizedDescription }
    }

    func connectSession() {
        pairingCandidate = nil
        errorMessage = nil
        showsPairing = true
    }

    func disconnect() {
        let topic = notificationsEnabled ? pairing?.pushTopic : nil
        PairingStorage.clear()
        pairing = nil
        resetRequests()
        voiceBridge.reset()
        isConnected = false
        phase = .disconnected
        connectionText = "Not connected"
        showsVoiceInput = false
        Task {
            // Send the revocation before closing the socket. On a lost network the
            // user can also unsubscribe in ntfy; backgrounding deliberately keeps push.
            guard pairing == nil else { return }
            if let topic { try? await relay.send(PushUnregister(type: "push_unregister", topic: topic)) }
            if pairing == nil { relay.disconnect() }
        }
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        notificationsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "ntfyEnabled")
        if !enabled, let pairing {
            Task {
                try? await relay.send(PushUnregister(type: "push_unregister", topic: pairing.pushTopic))
                startConnection()
            }
        } else { startConnection() }
    }

    func selectTab(_ tab: AliceTab) { selectedTab = tab }
    func loadNextRequest() {
        lastResponse = nil; lastChoice = nil
        phase = .waiting
        showNextCard()
    }

    func submitDecision(card: DecisionCard, option: DecisionOption) {
        guard isConnected, !isSending, !hasPendingResponse,
              currentDecision?.id == card.id, card.options.contains(option),
              card.expiresAt.map({ $0 > Date() }) ?? true else { return }
        lastResponse = DecisionResponse(id: card.id, optionId: option.id)
        lastChoice = option
        sendPendingResponse()
    }

    func retryDecision() { guard hasPendingResponse else { return }; sendPendingResponse() }

    private func sendPendingResponse() {
        guard isConnected, !isSending, let response = lastResponse,
              currentDecision?.id == response.id else { return }
        isSending = true
        errorMessage = nil
        sendingTimeout?.cancel()
        sendingTimeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(10)) } catch { return }
            guard let self, self.lastResponse?.id == response.id else { return }
            self.isSending = false
            self.errorMessage = "Delivery isn't confirmed yet. Retry the same decision."
        }
        Task {
            do { try await relay.send(response) }
            catch {
                guard lastResponse?.id == response.id else { return }
                isSending = false
                errorMessage = "Connection lost. Reconnect to retry your decision."
            }
        }
    }

    func makeVoiceInput() -> VoiceInputModel {
        let context = pairing.map { VoiceContext(sessionId: $0.sessionId, taskId: nil, decisionId: currentDecision?.id) }
        let services = isConnected && voiceAvailable ? VoiceServices(sessions: voiceBridge, inputs: voiceBridge) : nil
        return VoiceInputModel(services: services, context: context)
    }
    func openVoiceInput() { guard isConnected else { return }; showsVoiceInput = true }

    private func connectionChanged(_ state: RelayClient.State) {
        switch state {
        case .connecting:
            isConnected = false
            connectionText = "Connecting…"
            cards = []; currentDecision = nil
        case .connected:
            connectionText = "Waiting for Bob"
        case .offline:
            isConnected = false
            connectionText = pairing == nil ? "Not connected" : "Bob offline · reconnecting"
            showsVoiceInput = false
            voiceBridge.reset()
            isSending = false
        case .invalidPairing:
            disconnect()
            errorMessage = "This pairing has expired. Scan Bob's QR code again."
        }
    }

    private func receive(_ message: RelayEnvelope, data: Data) {
        guard pairing != nil else { return }
        voiceBridge.receive(message, data: data)
        switch message.type {
        case "paired", "bob_status":
            isConnected = message.bobOnline ?? message.online ?? false
            voiceAvailable = message.voiceAvailable ?? voiceAvailable
            connectionText = isConnected ? "Connected to Bob" : "Waiting for Bob"
            if isConnected && currentDecision == nil { phase = .waiting }
            if !isConnected { showsVoiceInput = false; voiceBridge.reset() }
        case "sync":
            let open = message.decisions ?? []
            cards = open.filter { $0.expiresAt.map { $0 > Date() } ?? true }
            if let pending = lastResponse, !cards.contains(where: { $0.id == pending.id }) {
                lastResponse = nil; lastChoice = nil; isSending = false
            }
            showNextCard()
        case "decision_request":
            guard let card = try? RelayClient.decoder().decode(DecisionCard.self, from: data),
                  card.expiresAt.map({ $0 > Date() }) ?? true else { return }
            if let index = cards.firstIndex(where: { $0.id == card.id }) { cards[index] = card }
            else { cards.append(card) }
            showNextCard()
        case "ack":
            guard let id = message.id, cards.contains(where: { $0.id == id }) else { return }
            let ownAnswer = lastResponse?.id == id
            let kind = cards.first(where: { $0.id == id })?.kind
            cards.removeAll { $0.id == id }
            if currentDecision?.id == id {
                currentDecision = nil
                sendingTimeout?.cancel(); isSending = false; errorMessage = nil
                if ownAnswer && kind == .approval {
                    switch lastChoice?.approvalChoice {
                    case .once: phase = .approvedOnce
                    case .task: phase = .approvedForTask
                    case .reject: phase = .rejected
                    case nil: phase = .answered
                    }
                } else { phase = .answered }
                if !cards.isEmpty { showNextCard() }
            }
        case "decision_expired":
            guard let id = message.id else { return }
            removeCard(id)
        case "error":
            if message.id == lastResponse?.id, message.id != nil {
                isSending = false; lastResponse = nil; lastChoice = nil
                sendingTimeout?.cancel()
                errorMessage = "Bob couldn't accept that answer. Please choose again."
            }
        case "notify":
            if let status = try? JSONDecoder().decode(StatusNotification.self, from: data) {
                latestStatus = status.message
            }
        default: break
        }
    }

    private func showNextCard() {
        let next = cards.first
        if currentDecision?.id != next?.id { showsVoiceInput = false }
        currentDecision = next
        if next != nil { phase = .needsDecision }
        else if phase == .needsDecision { phase = .waiting }
    }
    private func expireCards() {
        for card in cards where card.expiresAt.map({ $0 <= Date() }) ?? false { removeCard(card.id) }
    }
    private func removeCard(_ id: String) {
        cards.removeAll { $0.id == id }
        if currentDecision?.id == id {
            if lastResponse?.id == id { lastResponse = nil; lastChoice = nil }
            sendingTimeout?.cancel(); isSending = false
            latestStatus = "That request is no longer open. Waiting for Bob's next step."
            showNextCard()
        }
    }
    private func resetRequests() {
        cards = []; currentDecision = nil; lastResponse = nil; lastChoice = nil
        sendingTimeout?.cancel(); isSending = false
    }
    private struct PushUnregister: Encodable { let type: String; let topic: String }
}
