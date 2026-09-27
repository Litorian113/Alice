import Foundation

struct RelayEnvelope: Decodable {
    let type: String
    var id: String?
    var error: String?
    var online: Bool?
    var bobOnline: Bool?
    var decisions: [DecisionCard]?
    var voiceAvailable: Bool?
    var reason: String?
    var voiceReadyUntil: Date?
}

@MainActor
final class RelayClient {
    enum State { case connecting, connected, offline, invalidPairing }
    var onState: ((State) -> Void)?
    var onMessage: ((RelayEnvelope, Data) -> Void)?
    private var socket: URLSessionWebSocketTask?
    private var worker: Task<Void, Never>?
    private var handshake: Task<Void, Never>?
    private var ping: Task<Void, Never>?
    private var accepted = false
    private var generation = UUID()

    func connect(_ pairing: Pairing, pushTopic: String? = nil, pushClick: String? = nil) {
        disconnect()
        let attempt = UUID()
        generation = attempt
        worker = Task { [weak self] in
            var backoff = 1
            while !Task.isCancelled {
                guard let self, self.generation == attempt else { return }
                self.onState?(.connecting)
                let socket = URLSession.shared.webSocketTask(with: pairing.relayURL)
                self.socket = socket
                self.accepted = false
                socket.maximumMessageSize = 65_536
                socket.resume()
                self.handshake = Task {
                    do { try await Task.sleep(for: .seconds(12)) } catch { return }
                    socket.cancel(with: .goingAway, reason: nil)
                }
                do {
                    var hello: [String: String] = ["type": "hello", "role": "phone",
                        "sessionId": pairing.sessionId, "secret": pairing.secret]
                    if let pushTopic { hello["pushTopic"] = pushTopic }
                    if let pushClick { hello["pushClick"] = pushClick }
                    try await socket.send(.data(JSONSerialization.data(withJSONObject: hello)))
                    while !Task.isCancelled {
                        let message = try await socket.receive()
                        guard self.generation == attempt else { return }
                        let data: Data
                        switch message {
                        case .string(let text): data = Data(text.utf8)
                        case .data(let bytes): data = bytes
                        @unknown default: continue
                        }
                        guard let envelope = try? Self.decoder().decode(RelayEnvelope.self, from: data) else { continue }
                        if envelope.type == "error", envelope.id == nil, envelope.error == "wrong secret" {
                            self.disconnect()
                            self.onState?(.invalidPairing)
                            return
                        }
                        if envelope.type == "paired" {
                            self.handshake?.cancel()
                            self.accepted = true
                            backoff = 1
                            self.onState?(.connected)
                            self.startPings(socket)
                        }
                        self.onMessage?(envelope, data)
                    }
                } catch { /* Reconnect without exposing URLs, tokens or server internals. */ }
                socket.cancel(with: .goingAway, reason: nil)
                self.handshake?.cancel()
                self.ping?.cancel()
                self.accepted = false
                guard !Task.isCancelled, self.generation == attempt else { return }
                self.onState?(.offline)
                do { try await Task.sleep(for: .seconds(backoff)) } catch { return }
                backoff = min(backoff * 2, 10)
            }
        }
    }

    func send<T: Encodable>(_ message: T) async throws {
        guard let socket, accepted else { throw VoiceError.connection }
        let data = try JSONEncoder().encode(message)
        try await socket.send(.data(data))
    }

    func disconnect() {
        generation = UUID()
        worker?.cancel(); worker = nil
        handshake?.cancel(); handshake = nil
        ping?.cancel(); ping = nil
        socket?.cancel(with: .normalClosure, reason: nil); socket = nil
        accepted = false
    }

    private func startPings(_ socket: URLSessionWebSocketTask) {
        ping?.cancel()
        ping = Task {
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(20)) } catch { return }
                // A stalled connection must not leave approvals enabled indefinitely.
                let timeout = Task {
                    do { try await Task.sleep(for: .seconds(10)) } catch { return }
                    socket.cancel(with: .goingAway, reason: nil)
                }
                do {
                    try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
                        socket.sendPing { error in
                            if let error { c.resume(throwing: error) } else { c.resume() }
                        }
                    }
                } catch { socket.cancel(with: .goingAway, reason: nil) }
                timeout.cancel()
            }
        }
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { value in
            let text = try value.singleValueContainer().decode(String.self)
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = f.date(from: text) { return date }
            f.formatOptions = [.withInternetDateTime]
            guard let date = f.date(from: text) else { throw PairingError.invalid }
            return date
        }
        return decoder
    }
}
