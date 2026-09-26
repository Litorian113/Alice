import Foundation

@MainActor
final class AssemblyAITranscriber: SpeechTranscribing {
    private var socket: URLSessionWebSocketTask?
    private var receiver: Task<Void, Never>?
    private var deadline: Task<Void, Never>?
    private var continuation: AsyncThrowingStream<VoiceTranscriptEvent, Error>.Continuation?
    private var began = false
    private var finishing = false

    func connect(_ session: VoiceStreamingSession) throws -> AsyncThrowingStream<VoiceTranscriptEvent, Error> {
        guard socket == nil, session.expiresAt > Date(), !session.token.isEmpty,
              !session.speechModel.isEmpty,
              var url = URLComponents(url: session.websocketURL, resolvingAgainstBaseURL: false),
              url.scheme == "wss", url.path == "/v3/ws",
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.port == nil || url.port == 443,
              ["streaming.assemblyai.com", "streaming.eu.assemblyai.com", "streaming.us.assemblyai.com"].contains(url.host)
        else { throw VoiceError.invalidSession }

        url.queryItems = [
            URLQueryItem(name: "token", value: session.token),
            URLQueryItem(name: "speech_model", value: session.speechModel),
            URLQueryItem(name: "sample_rate", value: "16000"),
            URLQueryItem(name: "encoding", value: "pcm_s16le"),
            URLQueryItem(name: "inactivity_timeout", value: "15")
        ]
        guard let endpoint = url.url else { throw VoiceError.invalidSession }
        let stream = AsyncThrowingStream<VoiceTranscriptEvent, Error> { continuation = $0 }
        let task = URLSession.shared.webSocketTask(with: endpoint)
        socket = task
        began = false
        finishing = false
        task.resume()
        armTimeout(seconds: 15)
        receiver = Task { [weak self] in
            do {
                while !Task.isCancelled {
                    let message = try await task.receive()
                    try Task.checkCancellation()
                    guard let self else { return }
                    let data: Data
                    switch message {
                    case .data(let bytes): data = bytes
                    case .string(let string): data = Data(string.utf8)
                    @unknown default: continue
                    }
                    let event = try JSONDecoder().decode(Event.self, from: data)
                    switch event.type {
                    case "Begin":
                        guard !self.began else { continue }
                        self.began = true
                        self.deadline?.cancel()
                        self.continuation?.yield(.began)
                    case "Turn":
                        guard let order = event.turn_order, let text = event.transcript,
                              let isFinal = event.end_of_turn else { throw VoiceError.connection }
                        self.continuation?.yield(.turn(order: order, text: text, isFinal: isFinal))
                    case "Termination":
                        guard self.finishing else { throw VoiceError.incomplete }
                        self.continuation?.yield(.ended)
                        self.continuation?.finish()
                        self.close()
                        return
                    case "Error", "error": throw VoiceError.connection
                    default: break
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                self?.fail(VoiceError.connection)
            }
        }
        return stream
    }

    func sendAudio(_ data: Data) async throws {
        guard let socket, began, !finishing else { throw VoiceError.connection }
        try await socket.send(.data(data))
    }

    func finish() async throws {
        guard let socket, began, !finishing else { throw VoiceError.connection }
        finishing = true
        armTimeout(seconds: 10)
        try await socket.send(.string(#"{"type":"Terminate"}"#))
        // Receive the last final Turn and Termination before allowing Send.
    }

    func cancel() {
        continuation?.finish(throwing: CancellationError())
        continuation = nil
        receiver?.cancel()
        receiver = nil
        deadline?.cancel()
        deadline = nil
        guard let task = socket else { return }
        socket = nil
        // Best effort even on backgrounding/error; don't leave a billable session open.
        task.send(.string(#"{"type":"Terminate"}"#)) { _ in
            task.cancel(with: .normalClosure, reason: nil)
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            task.cancel(with: .goingAway, reason: nil)
        }
    }

    private func armTimeout(seconds: Int) {
        deadline?.cancel()
        deadline = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
            self?.fail(VoiceError.timeout)
        }
    }

    private func fail(_ error: Error) {
        continuation?.finish(throwing: error)
        cancel()
    }

    private func close() {
        deadline?.cancel()
        deadline = nil
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil
        continuation = nil
        receiver = nil
    }

    private struct Event: Decodable {
        let type: String
        var turn_order: Int?
        var transcript: String?
        var end_of_turn: Bool?
    }
}
