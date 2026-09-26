import SwiftUI

struct VoiceInputSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .medium))
                        .padding(12).background(Color.aliceSurfaceRaised, in: Circle())
                }.accessibilityLabel("Close microphone")
            }
            Spacer()
            AliceMascot(faceOnly: true).frame(width: 112, height: 91)
            Text("I'm all ears.").font(.plex(29, weight: .semibold))
            Image(systemName: "mic.fill")
                .font(.system(size: 31))
                .foregroundStyle(Color.aliceRecommended)
                .frame(width: 90, height: 90)
                .background(Color(hex: "EDE8FC"), in: Circle())
                .accessibilityHidden(true)
            // This UI has no recording service yet. Don't simulate listening or send invented transcripts.
            Text("Voice input isn't connected yet.")
                .font(.plex(14)).foregroundStyle(Color.aliceSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Back to Alice") { dismiss() }
                .font(.plex(15, weight: .medium)).frame(minHeight: 44)
        }
        .padding(24)
        .background(Color.aliceBackground)
        .foregroundStyle(Color.alicePrimary)
    }
}
