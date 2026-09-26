import Combine
import Foundation

@MainActor
final class VoiceInputModel: ObservableObject {
    enum Phase { case unavailable, idle, connecting, recording, finishing, review, sending, sent, failed }
    @Published private(set) var phase: Phase
    @Published private(set) var transcript = ""
    @Published private(set) var message: String?
    @Published private(set) var microphoneDenied = false

    private let services: VoiceServices?
    private let context: VoiceContext?
    private var recorder: (any VoiceRecording)?
    private var transcriber: (any SpeechTranscribing)?
    private var operation: Task<Void, Never>?
    private var audioTask: Task<Void, Never>?
    private var recordingLimit: Task<Void, Never>?
    private var draft: VoiceInput?
    private var turns = VoiceTranscript()
    private var generation = UUID()

    init(services: VoiceServices?, context: VoiceContext?) {
        self.services = services
        self.context = context
        phase = services != nil && context?.sessionId.isEmpty == false ? .idle : .unavailable
    }

    var isCapturing: Bool { phase == .connecting || phase == .recording || phase == .finishing }

    func start() {
        guard phase == .idle || phase == .failed || phase == .review,
              let services, let context else { return }
        cleanup()
        let attempt = UUID()
        generation = attempt
        transcript = ""
        turns = VoiceTranscript()
        draft = nil
        message = nil
        microphoneDenied = false
        phase = .connecting
        let recorder = services.makeRecorder()
        let transcriber = services.makeTranscriber()
        self.recorder = recorder
        self.transcriber = transcriber

        operation = Task { [weak self] in
            do {
                let allowed = await recorder.requestPermission()
                try Task.checkCancellation()
                guard allowed else { throw VoiceError.microphoneDenied }
                let session = try await services.sessions.createSession(context: context)
                try Task.checkCancellation()
                let events = try transcriber.connect(session)
                for try await event in events {
                    try Task.checkCancellation()
                    guard let self, self.generation == attempt else { return }
                    switch event {
                    case .began:
                        let chunks = try recorder.start()
                        self.phase = .recording
                        self.audioTask = Task { [weak self] in
                            do {
                                for try await chunk in chunks {
                                    try Task.checkCancellation()
                                    try await transcriber.sendAudio(chunk)
                                }
                                try Task.checkCancellation()
                                try await transcriber.finish()
                            } catch {
                                guard !Task.isCancelled, self?.generation == attempt else { return }
                                self?.fail(error)
                            }
                        }
                        self.recordingLimit = Task { [weak self] in
                            do { try await Task.sleep(for: .seconds(120)) } catch { return }
                            self?.stop()
                        }
                    case let .turn(order, text, isFinal):
                        self.turns.update(order: order, text: text, isFinal: isFinal)
                        self.transcript = self.turns.text
                    case .ended:
                        guard self.phase == .finishing else { throw VoiceError.incomplete }
                        guard !self.transcript.isEmpty else { throw VoiceError.emptyTranscript }
                        guard self.turns.isFinal else { throw VoiceError.incomplete }
                        self.draft = VoiceInput(context: context, text: self.transcript)
                        self.phase = .review
                        self.recordingLimit?.cancel()
                    }
                }
            } catch {
                guard !Task.isCancelled, self?.generation == attempt else { return }
                self?.fail(error)
            }
        }
    }

    func stop() {
        guard phase == .recording else { return }
        phase = .finishing
        recordingLimit?.cancel()
        recorder?.stop(flush: true)
        recordingLimit = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(15)) } catch { return }
            self?.fail(VoiceError.timeout)
        }
        // audioTask drains the remaining chunks, then sends Terminate.
    }

    func send() {
        guard phase == .review, let draft, let services else { return }
        phase = .sending
        message = nil
        let attempt = generation
        operation = Task { [weak self] in
            do {
                let receipt = try await services.inputs.send(draft)
                try Task.checkCancellation()
                guard let self, self.generation == attempt else { return }
                guard receipt.inputId == draft.id, receipt.status == "accepted" else { throw VoiceError.delivery }
                self.phase = .sent
            } catch {
                guard !Task.isCancelled, let self, self.generation == attempt else { return }
                self.phase = .review
                self.message = (error as? VoiceError ?? .delivery).localizedDescription
                // Keep this exact input ID for an idempotent retry after an ambiguous timeout.
            }
        }
    }

    func interrupt() {
        guard isCapturing else { return }
        fail(VoiceError.interrupted)
    }

    func cancel() {
        generation = UUID()
        cleanup()
    }

    private func fail(_ error: Error) {
        cleanup()
        phase = .failed
        let voiceError = error as? VoiceError ?? .connection
        if case .microphoneDenied = voiceError { microphoneDenied = true }
        message = voiceError.localizedDescription
    }

    private func cleanup() {
        operation?.cancel()
        audioTask?.cancel()
        recordingLimit?.cancel()
        recorder?.stop(flush: false)
        transcriber?.cancel()
        operation = nil
        audioTask = nil
        recordingLimit = nil
        recorder = nil
        transcriber = nil
    }
}
