import Foundation

/// Supply real endpoints and the relay's authentication at the composition root.
/// Never pass an AssemblyAI API key to this adapter.
@MainActor
final class HTTPVoiceBackend: VoiceSessionProviding, VoiceInputSending {
    typealias Authorize = (URLRequest) async throws -> URLRequest
    private let sessionEndpoint: URL
    private let inputEndpoint: URL
    private let authorize: Authorize
    private let transport: URLSession

    init(sessionEndpoint: URL, inputEndpoint: URL, transport: URLSession = .shared,
         authorize: @escaping Authorize) {
        self.sessionEndpoint = sessionEndpoint
        self.inputEndpoint = inputEndpoint
        self.transport = transport
        self.authorize = authorize
    }

    func createSession(context: VoiceContext) async throws -> VoiceStreamingSession {
        struct Body: Encodable { let context: VoiceContext }
        return try await post(Body(context: context), to: sessionEndpoint)
    }

    func send(_ input: VoiceInput) async throws -> VoiceInputReceipt {
        let receipt: VoiceInputReceipt = try await post(input, to: inputEndpoint, idempotencyKey: input.id)
        guard receipt.inputId == input.id, receipt.status == "accepted" else { throw VoiceError.delivery }
        return receipt
    }

    private func post<Body: Encodable, Response: Decodable>(
        _ body: Body, to endpoint: URL, idempotencyKey: UUID? = nil
    ) async throws -> Response {
        guard endpoint.scheme == "https", endpoint.host != nil else { throw VoiceError.unavailable }
        var request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let idempotencyKey {
            request.setValue(idempotencyKey.uuidString, forHTTPHeaderField: "Idempotency-Key")
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(body)
        request = try await authorize(request)
        try Task.checkCancellation()
        let (data, response) = try await transport.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw idempotencyKey == nil ? VoiceError.invalidSession : VoiceError.delivery
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: value) else { throw VoiceError.invalidSession }
            return date
        }
        return try decoder.decode(Response.self, from: data)
    }
}
