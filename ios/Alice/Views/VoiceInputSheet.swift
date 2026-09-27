import AVFoundation
import SwiftUI

struct VoiceInputView: View {
    @EnvironmentObject private var store: AliceSessionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("companionMotion") private var companionMotion = true
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var model: VoiceInputModel

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                Button { store.finishVoiceInput() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .medium))
                        .padding(12).background(Color.aliceSurfaceRaised, in: Circle())
                }
                .disabled(model.phase == .sending)
                .accessibilityLabel("Close microphone")
            }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {
                        AliceMascot(happy: model.phase == .sent)
                            .frame(width: 105, height: 125)
                            .rotationEffect(.degrees(model.phase == .recording ? -6 : 0))
                            .animation(reduceMotion || !companionMotion ? nil : .easeInOut(duration: 0.3), value: model.phase)
                        VStack(spacing: 8) {
                            Text(title).font(.plex(29, weight: .semibold))
                            Text(detail)
                                .font(.plex(14)).foregroundStyle(Color.aliceSecondary)
                                .multilineTextAlignment(.center)
                        }
                        if model.phase == .connecting || model.phase == .finishing || model.phase == .sending {
                            ProgressView().accessibilityLabel(title)
                        }
                        if !model.transcript.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("YOU").font(.plex(10, weight: .semibold)).foregroundStyle(Color.aliceAccent)
                                Text(model.transcript)
                                    .font(.plex(20)).lineSpacing(5).textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(model.transcript.utf16.count) / 500")
                                    .font(.plex(11)).foregroundStyle(model.transcript.utf16.count > 500 ? Color.aliceError : .aliceSecondary)
                            }
                            .padding(22)
                            .background(Color.aliceAccent.opacity(0.07), in: RoundedRectangle(cornerRadius: 24))
                            .padding(.leading, 20)
                        }
                        if let message = model.message {
                            Text(message).font(.plex(14))
                                .foregroundStyle(Color.aliceError)
                                .multilineTextAlignment(.center)
                        }
                        Color.clear.frame(height: 1).id("transcriptEnd")
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)
                .onChange(of: model.transcript) { _, _ in
                    proxy.scrollTo("transcriptEnd", anchor: .bottom)
                }
            }
            actions
        }
        .padding(24)
        .background(Color.aliceBackground)
        .foregroundStyle(Color.alicePrimary)
        .task(id: model.phase) {
            if model.phase == .sent {
                do { try await Task.sleep(for: .seconds(1.5)) } catch { return }
                store.finishVoiceInput()
            }
        }
        .onDisappear { model.cancel() }
        .onChange(of: scenePhase) { _, phase in
            // The permission prompt itself makes the app inactive while connecting.
            if phase == .background || (phase == .inactive && model.phase == .recording) {
                model.interrupt()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { notification in
            if let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
               type == AVAudioSession.InterruptionType.began.rawValue {
                model.interrupt()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { notification in
            if let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
               reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
                model.interrupt()
            }
        }
    }

    private var title: String {
        switch model.phase {
        case .unavailable, .idle, .failed: return "I'm all ears."
        case .connecting: return "Getting ready…"
        case .recording: return "I'm listening."
        case .finishing: return "One moment…"
        case .review: return "Ready to send?"
        case .sending: return "Sending your input…"
        case .sent: return "Input queued."
        }
    }

    private var detail: String {
        switch model.phase {
        case .unavailable: return "Voice isn't available for this session yet."
        case .idle: return "Hold the microphone below and speak to Bob. AssemblyAI transcribes your voice; you review before sending."
        case .connecting: return "Preparing your microphone and voice connection."
        case .recording: return "Keep holding while you speak. Release to review your words."
        case .finishing: return "Finishing your transcript."
        case .review:
            if store.currentDecision?.kind == .approval {
                return "This message will be queued. It does not approve the command; choose Approve or Reject separately."
            }
            if store.currentDecision?.acceptsVoice != true {
                return "Bob isn't waiting for a voice reply right now. Your message will be queued until he checks for input or opens the next voice dialog."
            }
            return "Review your words, then send them to continue this conversation with Bob."
        case .sending: return "Waiting for confirmation."
        case .sent: return "Your input is queued for Bob. His updates and decisions will appear here."
        case .failed: return "Please try recording again."
        }
    }

    @ViewBuilder private var actions: some View {
        switch model.phase {
        case .idle, .failed:
            if model.microphoneDenied {
                PrimaryButton(title: "Open Settings", icon: "gearshape") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            }
            PrimaryButton(title: model.phase == .failed ? "Record again" : "Start speaking", icon: "mic.fill") {
                model.start()
            }
        case .recording:
            PrimaryButton(title: "Stop recording", icon: "stop.fill") { model.stop() }
        case .review:
            PrimaryButton(title: "Send to Bob", icon: "arrow.up") { model.send() }
                .disabled(model.transcript.utf16.count > 500)
            Button("Record again") { model.start() }
                .font(.plex(15, weight: .medium)).frame(minHeight: 44)
        case .unavailable:
            PrimaryButton(title: "Back to Alice") { store.finishVoiceInput() }
        case .connecting, .finishing, .sending, .sent:
            EmptyView()
        }
    }
}
