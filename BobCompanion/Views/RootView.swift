import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: SessionStore

    var body: some View {
        ZStack {
            Color.bcBackground.ignoresSafeArea()
            Group {
                switch store.selectedTab {
                case .bob: ConnectedView()
                case .usage: UsageView()
                case .profile: ProfileView()
                }
            }
            .frame(maxWidth: 600)
        }
        .font(.plex(15))
        .foregroundStyle(Color.bcPrimary)
        .safeAreaInset(edge: .bottom, spacing: 0) { CompanionNavigation() }
        .sheet(isPresented: $store.showsInstruction) {
            InstructionSheet(voiceMode: store.prefersVoice)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
        }
        .tint(.bcAccent)
    }
}

struct CompanionNavigation: View {
    @EnvironmentObject var store: SessionStore
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    private var onBob: Bool { store.selectedTab == .bob }

    var body: some View {
        ZStack(alignment: .top) {
            NavigationNotch()
                .fill(.white)
                .shadow(color: Color.bcPrimary.opacity(0.06), radius: 18, y: -4)
                .ignoresSafeArea(edges: .bottom)
            HStack(alignment: .top, spacing: 0) {
                tab(.usage, icon: "chart.bar.xaxis")
                VStack(spacing: 8) {
                    Button {
                        if hapticsEnabled { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
                        if onBob {
                            if store.isDemoConnected { store.openInstruction(voice: true) }
                            else { store.connectDemo() }
                        } else { store.selectTab(.bob) }
                    } label: {
                        ZStack {
                            Circle().fill(LinearGradient(colors: [.bcAccent, Color(hex: "7160E8")], startPoint: .topLeading, endPoint: .bottomTrailing))
                            if onBob {
                                Image(systemName: store.isDemoConnected ? "mic.fill" : "plus")
                                    .font(.system(size: 27, weight: .medium))
                                    .foregroundStyle(.white)
                            } else {
                                BobMascot(faceOnly: true, animated: false)
                                    .frame(width: 49, height: 43)
                            }
                        }
                        .frame(width: 68, height: 68)
                        .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
                        .shadow(color: Color.bcAccent.opacity(0.26), radius: 12, y: 6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(onBob ? (store.isDemoConnected ? "Talk to Bob" : "Start demo session") : "Bob")
                    .accessibilityIdentifier("nav.bob")
                    Text(onBob ? (store.isDemoConnected ? "Talk to Bob" : "Meet Bob") : "Bob")
                        .font(.plex(11, weight: .medium, relativeTo: .caption))
                        .foregroundStyle(onBob ? Color.bcAccent : .bcSecondary)
                }
                .frame(width: 120)
                tab(.profile, icon: "person.crop.circle")
            }
            .padding(.horizontal, 24)
        }
        .frame(height: 101)
    }

    private func tab(_ tab: CompanionTab, icon: String) -> some View {
        Button {
            if hapticsEnabled { UISelectionFeedbackGenerator().selectionChanged() }
            store.selectTab(tab)
        } label: {
            VStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 23, weight: .regular))
                Text(tab.rawValue).font(.plex(12, weight: .medium, relativeTo: .caption))
            }
            .foregroundStyle(store.selectedTab == tab ? Color.bcAccent : .bcSecondary)
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

struct AppHeader: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text("bob").font(.plex(25, weight: .semibold, relativeTo: .title2))
            Text("companion").font(.plex(19)).foregroundStyle(Color.bcSecondary)
            Spacer()
            HStack(spacing: 5) {
                Circle().fill(Color.bcAccent).frame(width: 5, height: 5)
                Text("DEMO").font(.plex(9, weight: .semibold, relativeTo: .caption2)).tracking(1.2)
            }
            .foregroundStyle(Color.bcAccent)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.bcAccent.opacity(0.07), in: Capsule())
        }
        .padding(.vertical, 12)
    }
}

#Preview {
    RootView().environmentObject(SessionStore()).preferredColorScheme(.light)
}
