import AVFoundation

@MainActor
final class MicrophoneRecorder: VoiceRecording {
    private var engine: AVAudioEngine?
    private var encoder: PCMEncoder?

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
    }

    func start() throws -> AsyncThrowingStream<Data, Error> {
        stop(flush: false)
        let audio = AVAudioSession.sharedInstance()
        do {
            try audio.setCategory(.record, mode: .measurement, options: [])
            try audio.setActive(true)
            let engine = AVAudioEngine()
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw VoiceError.audio }
            var continuation: AsyncThrowingStream<Data, Error>.Continuation!
            let stream = AsyncThrowingStream<Data, Error>(bufferingPolicy: .bufferingOldest(20)) {
                continuation = $0
            }
            let encoder = try PCMEncoder(input: format, continuation: continuation)
            input.installTap(onBus: 0, bufferSize: 2048, format: format) { buffer, _ in
                encoder.append(buffer)
            }
            self.engine = engine
            self.encoder = encoder
            engine.prepare()
            try engine.start()
            return stream
        } catch {
            stop(flush: false)
            try? audio.setActive(false, options: .notifyOthersOnDeactivation)
            throw VoiceError.audio
        }
    }

    func stop(flush: Bool) {
        guard let engine else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        encoder?.finish(flush: flush)
        self.engine = nil
        encoder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// The audio callback and stop() can race. Keep conversion and final flushing under one lock.
private final class PCMEncoder: @unchecked Sendable {
    private let lock = NSLock()
    private let converter: AVAudioConverter
    private let output: AVAudioFormat
    private let continuation: AsyncThrowingStream<Data, Error>.Continuation
    private var pending = Data()
    private var finished = false
    private let chunkBytes = 3_200 // 100 ms, 16 kHz, mono, signed 16-bit little-endian.

    init(input: AVAudioFormat, continuation: AsyncThrowingStream<Data, Error>.Continuation) throws {
        guard let output = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000,
                                         channels: 1, interleaved: true),
              let converter = AVAudioConverter(from: input, to: output) else { throw VoiceError.audio }
        self.output = output
        self.converter = converter
        self.continuation = continuation
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return }
        let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * 16_000 / buffer.format.sampleRate)) + 64
        guard let converted = AVAudioPCMBuffer(pcmFormat: output, frameCapacity: capacity) else {
            fail(); return
        }
        var supplied = false
        var error: NSError?
        let status = converter.convert(to: converted, error: &error) { _, state in
            if supplied { state.pointee = .noDataNow; return nil }
            supplied = true
            state.pointee = .haveData
            return buffer
        }
        guard status != .error, error == nil, let samples = converted.int16ChannelData else {
            fail(); return
        }
        pending.append(Data(bytes: samples[0], count: Int(converted.frameLength) * 2))
        while pending.count >= chunkBytes && !finished {
            emit(Data(pending.prefix(chunkBytes)))
            pending.removeFirst(chunkBytes)
        }
    }

    func finish(flush: Bool) {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return }
        if flush {
            // Drain the resampler so the end of the last word isn't dropped.
            if let tail = AVAudioPCMBuffer(pcmFormat: output, frameCapacity: 1600) {
                var error: NSError?
                let status = converter.convert(to: tail, error: &error) { _, state in
                    state.pointee = .endOfStream
                    return nil
                }
                guard status != .error, error == nil else { fail(); return }
                if let samples = tail.int16ChannelData {
                    pending.append(Data(bytes: samples[0], count: Int(tail.frameLength) * 2))
                }
            }
            while !pending.isEmpty && !finished {
                let count = min(chunkBytes, pending.count)
                var chunk = Data(pending.prefix(count))
                pending.removeFirst(count)
                chunk.append(Data(repeating: 0, count: chunkBytes - count))
                emit(chunk)
            }
        }
        pending.removeAll()
        finished = true
        continuation.finish()
    }

    private func emit(_ data: Data) {
        if case .dropped = continuation.yield(data) {
            finished = true
            continuation.finish(throwing: VoiceError.backpressure)
        }
    }

    private func fail() {
        finished = true
        continuation.finish(throwing: VoiceError.audio)
    }
}
