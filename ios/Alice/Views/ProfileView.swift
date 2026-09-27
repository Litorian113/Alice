import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var store: AliceSessionStore
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("companionMotion") private var companionMotion = true
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    @AppStorage("displayName") private var displayName = "Franz Anhäupl"
    @State private var showsAccount = false
    @State private var showsAbout = false
    @State private var showsCustomizer = false

    private var initials: String {
        String(displayName.split(separator: " ").prefix(2).compactMap(\.first))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Your profile")
                    .font(.plex(34, weight: .semibold, relativeTo: .largeTitle)).tracking(-1)
                    .padding(.top, 24)
                Button { showsAccount = true } label: {
                    HStack(spacing: 15) {
                        Text(initials).font(.plex(22, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 62, height: 62)
                            .background(
                                LinearGradient(colors: [.aliceAccent, .aliceRecommended],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: Circle()
                            )
                        VStack(alignment: .leading, spacing: 4) {
                            Text("IBMid").font(.plex(11, weight: .medium)).foregroundStyle(Color.aliceSecondary)
                            Text(displayName).font(.plex(19, weight: .semibold))
                            // Prototype identity from Franz's reference; never store the full email here.
                            Text("franz.anhaeupl@…")
                                .font(.plex(13)).foregroundStyle(Color.aliceSecondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.aliceSecondary)
                    }
                    .padding(20).aliceSurface()
                }.buttonStyle(.plain).accessibilityIdentifier("profile.identity")
                connection
                VStack(alignment: .leading, spacing: 0) {
                    Eyebrow(text: "Make yourself at home").padding(.bottom, 13)
                    Button { showsAccount = true } label: {
                        settingsRow("Account settings", subtitle: "Your name and profile", icon: "person.crop.circle")
                    }.buttonStyle(.plain).accessibilityIdentifier("profile.account")
                    Divider().overlay(Color.aliceBorder)
                    Button { store.showsNotifications = true } label: {
                        settingsRow("Notifications", subtitle: store.pairing != nil && store.notificationsEnabled
                                    ? "Manage your ntfy notifications" : "Set up notifications with ntfy", icon: "bell")
                    }.buttonStyle(.plain).accessibilityIdentifier("profile.notifications")
                    Divider().overlay(Color.aliceBorder)
                    Button { showsCustomizer = true } label: {
                        HStack(spacing: 12) {
                            AliceMascot(faceOnly: true, animated: false)
                                .frame(width: 36, height: 32)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("An Alice that suits you").font(.plex(14, weight: .medium))
                                Text("Colors and gradients").font(.plex(11)).foregroundStyle(Color.aliceSecondary)
                            }
                            Spacer(minLength: 3)
                            Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(Color.aliceMuted)
                        }
                        .padding(.vertical, 16).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("profile.customizer")
                    Divider().overlay(Color.aliceBorder)
                    Toggle(isOn: $darkModeEnabled) {
                        settingsRow("Dark mode", subtitle: "A softer glow after hours", icon: "moon", chevron: false)
                    }.tint(.aliceAccent).accessibilityIdentifier("profile.darkMode")
                    Divider().overlay(Color.aliceBorder)
                    Toggle(isOn: $hapticsEnabled) {
                        settingsRow("Haptic feedback", subtitle: "A little tap for your decisions", icon: "hand.tap", chevron: false)
                    }.tint(.aliceAccent)
                    Divider().overlay(Color.aliceBorder)
                    Toggle(isOn: $companionMotion) {
                        settingsRow("Companion motion", subtitle: "Let Alice bounce and blink", icon: "sparkles", chevron: false)
                    }.tint(.aliceAccent)
                    Divider().overlay(Color.aliceBorder)
                    Button { showsAbout = true } label: {
                        settingsRow("About Alice", subtitle: "Made for a little more freedom", icon: "info.circle")
                    }.buttonStyle(.plain)
                }.padding(20).aliceSurface()
                HStack(spacing: 7) {
                    Image(systemName: "heart").font(.system(size: 11))
                    Text("Let Bob work. Step in when it matters.").font(.plex(11))
                }
                .foregroundStyle(Color.aliceSecondary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 22)
            }.padding(.horizontal, 24)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showsCustomizer) {
            AliceCustomizerView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsAccount) {
            AccountSettingsSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsAbout) {
            VStack(spacing: 18) {
                AliceMascot(happy: true).frame(width: 116, height: 139)
                Text("Alice").font(.plex(28, weight: .semibold))
                Text("Your companion for Bob.")
                    .font(.plex(15)).multilineTextAlignment(.center)
                Text("IBM Bob 2.0 Hackathon · September 2026\nFranz Anhäupl & Christopher Pietsch\nVersion 1.0")
                    .font(.plex(12)).foregroundStyle(Color.aliceSecondary).multilineTextAlignment(.center).lineSpacing(5)
                Button("Done") { showsAbout = false }.font(.plex(15, weight: .medium))
            }
            .padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.aliceBackground)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var connection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Eyebrow(text: "Your connection")
                Spacer()
                HStack(spacing: 5) {
                    Circle().fill(store.isConnected ? Color.aliceSuccess : .aliceMuted).frame(width: 6, height: 6)
                    Text(store.connectionText)
                        .font(.plex(11, weight: .medium))
                        .foregroundStyle(store.isConnected ? Color.aliceSuccess : .aliceSecondary)
                }
            }
            HStack(spacing: 13) {
                Image(systemName: "laptopcomputer").font(.system(size: 27)).foregroundStyle(Color.aliceAccent)
                    .frame(width: 48, height: 48).background(Color.aliceSurfaceRaised, in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.pairing != nil ? "Bob's workspace" : "No IDE connected")
                        .font(.plex(16, weight: .medium))
                    Text(store.pairing?.relayURL.host ?? "Connect to meet your companion.")
                        .font(.plex(12)).foregroundStyle(Color.aliceSecondary)
                }
            }
            Button {
                if store.pairing != nil { store.disconnect() }
                else { store.connectSession() }
            } label: {
                Label(store.pairing != nil ? "Disconnect this session" : "Connect session",
                      systemImage: store.isConnected ? "link.badge.plus" : "link")
                    .font(.plex(13, weight: .medium))
                    .foregroundStyle(store.isConnected ? Color.aliceError : .aliceAccent)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(store.isConnected ? Color.aliceError.opacity(0.05) : Color.aliceAccent.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain).accessibilityIdentifier("profile.connection")
        }.padding(20).aliceSurface()
    }

    private func settingsRow(_ title: String, subtitle: String, icon: String, chevron: Bool = true) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(Color.aliceSecondary).frame(width: 23)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.plex(14, weight: .medium))
                Text(subtitle).font(.plex(11)).foregroundStyle(Color.aliceSecondary)
            }
            Spacer(minLength: 3)
            if chevron { Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(Color.aliceMuted) }
        }.padding(.vertical, 16).contentShape(Rectangle())
    }
}

private struct AccountSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("displayName") private var displayName = "Franz Anhäupl"
    @State private var draft = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Account settings").font(.plex(25, weight: .semibold))
                    Spacer()
                    Button("Cancel") { dismiss() }.font(.plex(13))
                }
                Eyebrow(text: "Display name")
                TextField("Your name", text: $draft).font(.plex(17))
                    .textContentType(.name).padding(16).aliceSurface(radius: 14)
                Text("This profile is stored on your phone. IBM account sign-in will be available when the account connection is ready.")
                    .font(.plex(13)).foregroundStyle(Color.aliceSecondary)
                PrimaryButton(title: "Save profile", icon: "checkmark") {
                    displayName = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    dismiss()
                }.disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.padding(26).padding(.top, 12)
        }
        .background(Color.aliceBackground)
        .onAppear { draft = displayName }
    }
}
