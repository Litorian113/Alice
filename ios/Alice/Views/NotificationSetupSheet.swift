import SwiftUI

struct NotificationSetupSheet: View {
    @EnvironmentObject private var store: AliceSessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text("A little heads-up.").font(.plex(27, weight: .semibold))
                    Spacer()
                    Button("Done") { dismiss() }.frame(minHeight: 44)
                }
                Text("Get a notification when Bob needs you, even while Alice is closed. For now, the free ntfy app delivers it. Open Alice to make your decision.")
                    .font(.plex(15)).foregroundStyle(Color.aliceSecondary)
                Link("1. Install ntfy", destination: URL(string: "https://apps.apple.com/app/ntfy/id1625396347")!)
                    .font(.plex(17, weight: .medium)).frame(minHeight: 44)
                Text("2. In ntfy, allow notifications and subscribe to this topic on ntfy.sh:")
                    .font(.plex(15))
                if let pairing = store.pairing {
                    Text(pairing.pushTopic).font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled).padding(16).aliceSurface()
                    Button(copied ? "Copied" : "Copy topic") {
                        UIPasteboard.general.string = pairing.pushTopic
                        copied = true
                    }.frame(minHeight: 44)
                    Toggle("3. Send me notifications", isOn: Binding(
                        get: { store.notificationsEnabled }, set: { store.setNotificationsEnabled($0) }
                    )).font(.plex(16, weight: .medium)).tint(.aliceAccent)
                    Text("After subscribing, ask Bob to send a question. Your answer is always made inside Alice.")
                        .font(.plex(13)).foregroundStyle(Color.aliceSecondary)
                } else {
                    Text("Connect to Bob first to create your notification topic.").font(.plex(15))
                }
            }.padding(24)
        }.background(Color.aliceBackground)
    }
}
