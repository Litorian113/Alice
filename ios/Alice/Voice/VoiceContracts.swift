import Foundation

// These are Alice contracts, not AssemblyAI payloads. See docs/VOICE_INTEGRATION.md.
struct VoiceContext: Codable, Equatable {
    let sessionId: String
    let taskId: String?
    let decisionId: String?
}

struct VoiceInput: Codable {
    let id: UUID
    let type: String
    let source: String
    let context: VoiceContext
    let text: String
    let createdAt: Date

    init(context: VoiceContext, text: String) {
        id = UUID()
        type = "user_input"
        source = "voice"
        self.context = context
        self.text = text
        createdAt = Date()
    }
}

struct VoiceInputReceipt: Codable {
    let inputId: UUID
    let status: String
}

struct VoiceStreamingSession: Codable {
    let token: String
    let expiresAt: Date
    let websocketURL: URL
    let speechModel: String
}

@MainActor protocol VoiceSessionProviding {
    func createSession(context: VoiceContext) async throws -> VoiceStreamingSession
}

@MainActor protocol VoiceInputSending {
    func send(_ input: VoiceInput) async throws -> VoiceInputReceipt
}

enum VoiceTranscriptEvent {
    case began
    case turn(order: Int, text: String, isFinal: Bool)
    case ended
}

@MainActor protocol SpeechTranscribing: AnyObject {
    func connect(_ session: VoiceStreamingSession) throws -> AsyncThrowingStream<VoiceTranscriptEvent, Error>
    func sendAudio(_ data: Data) async throws
    func finish() async throws
    func cancel()
}

@MainActor protocol VoiceRecording: AnyObject {
    func requestPermission() async -> Bool
    func start() throws -> AsyncThrowingStream<Data, Error>
    func stop(flush: Bool)
}

@MainActor struct VoiceServices {
    let sessions: any VoiceSessionProviding
    let inputs: any VoiceInputSending
    var makeTranscriber: () -> any SpeechTranscribing = { AssemblyAITranscriber() }
    var makeRecorder: () -> any VoiceRecording = { MicrophoneRecorder() }
}

enum VoiceError: LocalizedError {
    case unavailable, microphoneDenied, audio, invalidSession, connection, timeout
    case backpressure, incomplete, emptyTranscript, delivery, interrupted, inputTooLong

    var errorDescription: String? {
        switch self {
        case .unavailable: return "Voice input isn't connected yet."
        case .microphoneDenied: return "Allow microphone access in Settings to talk to Alice."
        case .audio: return "The microphone couldn't start. Please try again."
        case .invalidSession: return "Voice couldn't connect. Please try again."
        case .connection: return "The voice connection was lost. Please record again."
        case .timeout: return "The voice service took too long. Please record again."
        case .backpressure: return "The connection couldn't keep up with your voice. Please record again."
        case .incomplete: return "Your recording couldn't be completed. Please record again."
        case .emptyTranscript: return "I didn't catch any words. Please try again."
        case .delivery: return "Delivery couldn't be confirmed. You can retry sending this input."
        case .interrupted: return "Recording stopped. Please record again when you're ready."
        case .inputTooLong: return "Please record a shorter message (up to 500 characters)."
        }
    }
}

// Turn updates replace earlier versions, including formatted finals; they never append twice.
struct VoiceTranscript {
    private var turns: [Int: (text: String, isFinal: Bool)] = [:]

    mutating func update(order: Int, text: String, isFinal: Bool) {
        guard turns[order]?.isFinal != true || isFinal else { return }
        turns[order] = (text, isFinal)
    }

    var text: String {
        turns.keys.sorted().compactMap { turns[$0]?.text }
            .joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isFinal: Bool { !turns.isEmpty && turns.values.allSatisfy(\.isFinal) }
}
