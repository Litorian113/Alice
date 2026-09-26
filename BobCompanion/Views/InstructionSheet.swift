import SwiftUI

struct InstructionSheet: View {
    @EnvironmentObject var store: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State var voiceMode: Bool
    @State private var text = ""
    @FocusState private var textFocused: Bool
    private var canSend: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack {
                    Eyebrow(text: "A word with Bob")
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .medium))
                            .padding(12).background(Color.bcSurfaceRaised, in: Circle())
                    }.accessibilityLabel("Close instruction")
                }
                BobMascot(faceOnly: true).frame(width: 91, height: 75)
                VStack(spacing: 7) {
                    Text(voiceMode ? "I'm all ears." : "What's on your mind?")
                        .font(.plex(29, weight: .semibold))
                    Text("A quick thought. A new direction. Your call.")
                        .font(.plex(14)).foregroundStyle(Color.bcSecondary)
                }
                Picker("Instruction mode", selection: $voiceMode) {
                    Text("Voice preview").tag(true)
                    Text("Type a message").tag(false)
                }
                .pickerStyle(.segmented)
                if voiceMode {
                    VStack(spacing: 16) {
                        HStack(spacing: 5) {
                            ForEach(0..<27) { index in
                                Capsule().fill(Color.bcAccent.opacity(text.isEmpty ? 0.25 : 0.8))
                                    .frame(width: 4, height: CGFloat([12, 20, 32, 19, 44, 28, 52, 34, 18][index % 9]))
                            }
                        }.frame(height: 60).accessibilityHidden(true)
                        Button {
                            text = "Stop after the tests and leave the API unchanged."
                        } label: {
                            Label("Try a demo phrase", systemImage: "mic.fill")
                                .font(.plex(15, weight: .medium))
                        }
                        Text("Voice preview uses a sample phrase.\nMicrophone recording isn't connected yet.")
                            .font(.plex(12)).foregroundStyle(Color.bcSecondary).multilineTextAlignment(.center)
                    }.padding(22).frame(maxWidth: .infinity).companionSurface()
                }
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: voiceMode ? "Review your message" : "Your instruction")
                    TextField("Tell Bob what to do…", text: $text, axis: .vertical)
                        .font(.plex(17)).lineLimit(3...6)
                        .focused($textFocused)
                        .padding(18).companionSurface(radius: 18)
                        .accessibilityIdentifier("instruction.text")
                }
                PrimaryButton(title: "Send to demo session", icon: "arrow.up") {
                    store.sendInstruction(text)
                }
                .disabled(!canSend)
                .opacity(canSend ? 1 : 0.45)
                .accessibilityIdentifier("instruction.send")
            }
            .padding(24).padding(.top, 12)
        }
        .background(Color.bcBackground)
        .foregroundStyle(Color.bcPrimary)
        .onAppear { if !voiceMode { textFocused = true } }
    }
}
