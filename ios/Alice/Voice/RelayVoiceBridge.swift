import Foundation

@MainActor
final class RelayVoiceBridge: VoiceSessionProviding, VoiceInputSending {
    private let relay: RelayClient
    private var tokenRequests: [String: CheckedContinuation<VoiceStreamingSession, Error>] = [:]
    private var inputRequests: [String: CheckedContinuation<VoiceInputReceipt, Error>] = [:]
    private var timeouts: [String: Task<Void, Never>] = [:]

    init(relay: RelayClient) { self.relay = relay }

    func createSession(context: VoiceContext) async throws -> VoiceStreamingSession {
        let id = UUID().uuidString
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { c in
                tokenRequests[id] = c
                dispatch(Request(type: "voice_session_request", id: id, text: nil), id: id)
            }
        } onCancel: { Task { @MainActor in self.fail(id, error: CancellationError()) } }
    }

    func send(_ input: VoiceInput) async throws -> VoiceInputReceipt {
        guard input.text.utf16.count <= 500 else { throw VoiceError.inputTooLong }
        let id = input.id.uuidString
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { c in
                inputRequests[id] = c
                dispatch(Request(type: "instruction", id: id, text: input.text), id: id)
            }
        } onCancel: { Task { @MainActor in self.fail(id, error: CancellationError()) } }
    }

    private func dispatch(_ request: Request, id: String) {
        timeouts[id] = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(20)) } catch { return }
            self?.fail(id, error: VoiceError.delivery)
        }
        Task {
            do { try await relay.send(request) } catch { fail(id, error: VoiceError.connection) }
        }
    }

    func receive(_ message: RelayEnvelope, data: Data) {
        guard let id = message.id else { return }
        if message.type == "ack", let c = inputRequests.removeValue(forKey: id), let uuid = UUID(uuidString: id) {
            timeouts.removeValue(forKey: id)?.cancel()
            c.resume(returning: VoiceInputReceipt(inputId: uuid, status: "accepted"))
        } else if message.type == "voice_session", let c = tokenRequests.removeValue(forKey: id) {
            timeouts.removeValue(forKey: id)?.cancel()
            do { c.resume(returning: try RelayClient.decoder().decode(VoiceStreamingSession.self, from: data)) }
            catch { c.resume(throwing: VoiceError.invalidSession) }
        } else if message.type == "error" { fail(id, error: VoiceError.delivery) }
    }

    func reset() {
        for id in Set(tokenRequests.keys).union(inputRequests.keys) { fail(id, error: VoiceError.connection) }
    }
    private func fail(_ id: String, error: Error) {
        timeouts.removeValue(forKey: id)?.cancel()
        tokenRequests.removeValue(forKey: id)?.resume(throwing: error)
        inputRequests.removeValue(forKey: id)?.resume(throwing: error)
    }
    private struct Request: Encodable { let type: String; let id: String; let text: String? }
}
