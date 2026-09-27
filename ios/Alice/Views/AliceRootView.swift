import SwiftUI

struct AliceRootView: View {
    @EnvironmentObject var store: AliceSessionStore

    var body: some View {
        ZStack {
            Color.aliceBackground.ignoresSafeArea()
            Group {
                switch store.selectedTab {
                case .alice: AliceHomeView()
                case .usage: UsageView()
                case .profile: ProfileView()
                }
            }
            .frame(maxWidth: 600)
        }
        .font(.plex(15))
        .foregroundStyle(Color.alicePrimary)
        .safeAreaInset(edge: .bottom, spacing: 0) { AliceNavigation() }
        .sheet(isPresented: $store.showsVoiceInput) {
            VoiceInputSheet(model: store.makeVoiceInput())
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
        }
        .tint(.aliceAccent)
        .sheet(isPresented: $store.showsPairing) {
            PairingSheet().presentationDragIndicator(.visible).presentationCornerRadius(32)
        }
        .sheet(isPresented: $store.showsNotifications) {
            NotificationSetupSheet().presentationDragIndicator(.visible).presentationCornerRadius(32)
        }
    }
}

struct AliceNavigation: View {
    @EnvironmentObject var store: AliceSessionStore
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    private var onAlice: Bool { store.selectedTab == .alice }

    var body: some View {
        ZStack(alignment: .top) {
            NavigationNotch()
                .fill(Color.aliceSurface)
                .shadow(color: Color.black.opacity(0.06), radius: 18, y: -4)
                .ignoresSafeArea(edges: .bottom)
            HStack(alignment: .top, spacing: 0) {
                tab(.usage, icon: "chart.bar.xaxis")
                VStack(spacing: 8) {
                    Button {
                        if hapticsEnabled { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
                        if onAlice {
                            if store.isConnected { store.openVoiceInput() }
                            else { store.connectSession() }
                        } else { store.selectTab(.alice) }
                    } label: {
                        ZStack {
                            Circle().fill(LinearGradient(colors: [.aliceAccent, Color(hex: "7160E8")], startPoint: .topLeading, endPoint: .bottomTrailing))
                            if onAlice {
                                Image(systemName: store.isConnected ? "mic.fill" : "plus")
                                    .font(.system(size: 27, weight: .medium))
                                    .foregroundStyle(.white)
                            } else {
                                AliceMascot(faceOnly: true, animated: false)
                                    .frame(width: 49, height: 43)
                            }
                        }
                        .frame(width: 68, height: 68)
                        .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
                        .shadow(color: Color.aliceAccent.opacity(0.26), radius: 12, y: 6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(onAlice ? (store.isConnected ? "Talk to Alice" : "Connect to Bob") : "Alice")
                    .accessibilityIdentifier("nav.alice")
                }
                .frame(width: 120)
                tab(.profile, icon: "person.crop.circle")
            }
            .padding(.horizontal, 24)
        }
        .frame(height: 101)
    }

    private func tab(_ tab: AliceTab, icon: String) -> some View {
        Button {
            if hapticsEnabled { UISelectionFeedbackGenerator().selectionChanged() }
            store.selectTab(tab)
        } label: {
            VStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 23, weight: .regular))
                Text(tab.rawValue).font(.plex(12, weight: .medium, relativeTo: .caption))
            }
            .foregroundStyle(store.selectedTab == tab ? Color.aliceAccent : .aliceSecondary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 58)
            .contentShape(Rectangle())
            .padding(.top, 30)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("nav.\(tab.rawValue.lowercased())")
        .accessibilityAddTraits(store.selectedTab == tab ? .isSelected : [])
    }
}

private struct NavigationNotch: Shape {
    func path(in rect: CGRect) -> Path {
        let mid = rect.midX
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 24))
        path.addLine(to: CGPoint(x: mid - 86, y: 24))
        path.addCurve(to: CGPoint(x: mid, y: 78), control1: CGPoint(x: mid - 48, y: 24), control2: CGPoint(x: mid - 53, y: 78))
        path.addCurve(to: CGPoint(x: mid + 86, y: 24), control1: CGPoint(x: mid + 53, y: 78), control2: CGPoint(x: mid + 48, y: 24))
        path.addLine(to: CGPoint(x: rect.maxX, y: 24))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct AliceHeader: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text("Alice").font(.plex(25, weight: .semibold, relativeTo: .title2))
            Spacer()

        }
        .padding(.vertical, 12)
    }
}

#Preview {
    AliceRootView().environmentObject(AliceSessionStore()).preferredColorScheme(.light)
}
