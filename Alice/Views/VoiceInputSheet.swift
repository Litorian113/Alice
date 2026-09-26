import AVFoundation
import SwiftUI

struct VoiceInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model: VoiceInputModel

    init(model: VoiceInputModel) {
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                Button { model.cancel(); dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .medium))
                        .padding(12).background(Color.aliceSurfaceRaised, in: Circle())
                }
                .disabled(model.phase == .sending)
                .accessibilityLabel("Close microphone")
            }
            ScrollView {
                VStack(spacing: 22) {
                    AliceMascot(faceOnly: true).frame(width: 112, height: 91)
                    Text(title).font(.plex(29, weight: .semibold))
                    Image(systemName: model.phase == .sent ? "checkmark" : "mic.fill")
                        .font(.system(size: 31))
                        .foregroundStyle(Color.aliceRecommended)
                        .frame(width: 90, height: 90)
                        .background(Color(hex: "EDE8FC"), in: Circle())
                        .accessibilityHidden(true)
                    Text(detail)
                        .font(.plex(14)).foregroundStyle(Color.aliceSecondary)
                        .multilineTextAlignment(.center)
                    if !model.transcript.isEmpty {
                        Text(model.transcript)
                            .font(.plex(18)).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20).aliceSurface()
                    }
                    if let message = model.message {
                        Text(message).font(.plex(14))
                            .foregroundStyle(Color.aliceError)
                            .multilineTextAlignment(.center)
                    }
                    if model.phase == .connecting || model.phase == .finishing || model.phase == .sending {
                        ProgressView().accessibilityLabel(title)
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 16)
            }
            actions
        }
        .padding(24)
        .background(Color.aliceBackground)
        .foregroundStyle(Color.alicePrimary)
        .interactiveDismissDisabled(model.phase == .sending)
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
        case .sent: return "Input received."
        }
    }

    private var detail: String {
        switch model.phase {
        case .unavailable: return "Voice input isn't connected yet."
        case .idle: return "Speak your feedback or instructions for Bob. Audio is transcribed by AssemblyAI. You review the text before sending."
        case .connecting: return "Preparing your microphone and voice connection."
        case .recording: return "Tell Bob what's on your mind. Tap Stop when you're done."
        case .finishing: return "Finishing your transcript."
        case .review: return "Review your words, then send them to your connected session."
        case .sending: return "Waiting for confirmation."
        case .sent: return "Your connected session accepted your input."
        case .failed: return "Nothing was sent to Bob."
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
            Button("Record again") { model.start() }
                .font(.plex(15, weight: .medium)).frame(minHeight: 44)
        case .unavailable, .sent:
            PrimaryButton(title: "Back to Alice") { dismiss() }
        case .connecting, .finishing, .sending:
            EmptyView()
        }
    }
}
