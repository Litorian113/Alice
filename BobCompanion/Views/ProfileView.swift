import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var store: SessionStore
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("companionMotion") private var companionMotion = true
    @AppStorage("displayName") private var displayName = "Franz Anhäupl"
    @State private var showsAccount = false
    @State private var showsAbout = false

    private var initials: String {
        String(displayName.split(separator: " ").prefix(2).compactMap(\.first))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                AppHeader()
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(text: "Your side of the team")
                    Text("Your profile").font(.plex(34, weight: .semibold, relativeTo: .largeTitle)).tracking(-1)
                    Text("A home for the human in the loop.")
                        .font(.plex(15)).foregroundStyle(Color.bcSecondary)
                }
                HStack(spacing: 15) {
                    Text(initials).font(.plex(22, weight: .medium))
                        .foregroundStyle(Color.bcRecommended)
                        .frame(width: 62, height: 62)
                        .background(Color(hex: "EEE8FC"), in: RoundedRectangle(cornerRadius: 22))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayName).font(.plex(19, weight: .semibold))
                        Text("Builder & Bob's teammate").font(.plex(12)).foregroundStyle(Color.bcSecondary)
                        Text("LOCAL DEMO PROFILE").font(.plex(8, weight: .medium)).tracking(1).foregroundStyle(Color.bcRecommended)
                    }
                    Spacer(minLength: 0)
                }.padding(20).companionSurface()
                connection
                VStack(alignment: .leading, spacing: 0) {
                    Eyebrow(text: "Make yourself at home").padding(.bottom, 13)
                    Button { showsAccount = true } label: {
                        settingsRow("Account settings", subtitle: "Your name and profile", icon: "person.crop.circle")
                    }.buttonStyle(.plain).accessibilityIdentifier("profile.account")
                    Divider().overlay(Color.bcBorder)
                    Toggle(isOn: $hapticsEnabled) {
                        settingsRow("Haptic feedback", subtitle: "A little tap for your decisions", icon: "hand.tap", chevron: false)
                    }.tint(.bcAccent)
                    Divider().overlay(Color.bcBorder)
                    Toggle(isOn: $companionMotion) {
                        settingsRow("Companion motion", subtitle: "Let Bob bounce and blink", icon: "sparkles", chevron: false)
                    }.tint(.bcAccent)
                    Divider().overlay(Color.bcBorder)
                    Button { showsAbout = true } label: {
                        settingsRow("About Bob Companion", subtitle: "Made for a little more freedom", icon: "info.circle")
                    }.buttonStyle(.plain)
                }.padding(20).companionSurface()
                HStack(spacing: 7) {
                    Image(systemName: "heart").font(.system(size: 11))
                    Text("Let Bob work. Step in when it matters.").font(.plex(11))
                }
                .foregroundStyle(Color.bcSecondary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 22)
            }.padding(.horizontal, 24)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showsAccount) {
            AccountSettingsSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsAbout) {
            VStack(spacing: 18) {
                BobMascot(happy: true).frame(width: 116, height: 139)
                Text("Bob Companion").font(.plex(28, weight: .semibold))
                Text("Let Bob work. Step in when it matters.")
                    .font(.plex(15)).multilineTextAlignment(.center)
                Text("IBM Bob 2.0 Hackathon · September 2026\nFranz Anhäupl & Christopher Pietsch\nApp prototype · Version 1.0")
                    .font(.plex(12)).foregroundStyle(Color.bcSecondary).multilineTextAlignment(.center).lineSpacing(5)
                Button("Done") { showsAbout = false }.font(.plex(15, weight: .medium))
            }
            .padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.bcBackground)
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
                    Circle().fill(store.isDemoConnected ? Color.bcSuccess : .bcMuted).frame(width: 6, height: 6)
                    Text(store.isDemoConnected ? "Demo connected" : "Disconnected")
                        .font(.plex(11, weight: .medium))
                        .foregroundStyle(store.isDemoConnected ? Color.bcSuccess : .bcSecondary)
                }
            }
            HStack(spacing: 13) {
                Image(systemName: "laptopcomputer").font(.system(size: 27)).foregroundStyle(Color.bcAccent)
                    .frame(width: 48, height: 48).background(Color.bcSurfaceRaised, in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.isDemoConnected ? "Bob's demo workspace" : "No IDE connected")
                        .font(.plex(16, weight: .medium))
                    Text(store.isDemoConnected ? "bob-companion · Auth refactor" : "Start a demo to meet your companion.")
                        .font(.plex(12)).foregroundStyle(Color.bcSecondary)
                }
            }
            Button {
                if store.isDemoConnected { store.disconnect() }
                else { store.connectDemo() }
            } label: {
                Label(store.isDemoConnected ? "Disconnect demo session" : "Connect demo session",
                      systemImage: store.isDemoConnected ? "link.badge.plus" : "link")
                    .font(.plex(13, weight: .medium))
                    .foregroundStyle(store.isDemoConnected ? Color.bcError : .bcAccent)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(store.isDemoConnected ? Color.bcError.opacity(0.05) : Color.bcAccent.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain).accessibilityIdentifier("profile.connection")
        }.padding(20).companionSurface()
    }

    private func settingsRow(_ title: String, subtitle: String, icon: String, chevron: Bool = true) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(Color.bcSecondary).frame(width: 23)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.plex(14, weight: .medium))
                Text(subtitle).font(.plex(11)).foregroundStyle(Color.bcSecondary)
            }
            Spacer(minLength: 3)
            if chevron { Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(Color.bcMuted) }
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
                    .textContentType(.name).padding(16).companionSurface(radius: 14)
                Text("This profile is stored on your phone. IBM account sign-in will be available when the account connection is ready.")
                    .font(.plex(13)).foregroundStyle(Color.bcSecondary)
                PrimaryButton(title: "Save profile", icon: "checkmark") {
                    displayName = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    dismiss()
                }.disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.padding(26).padding(.top, 12)
        }
        .background(Color.bcBackground)
        .onAppear { draft = displayName }
    }
}
