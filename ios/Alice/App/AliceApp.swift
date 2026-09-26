import SwiftUI

@main
struct AliceApp: App {
    @StateObject private var store = AliceSessionStore()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                AliceRootView()
                if showsSplash { AliceSplashView().transition(.opacity).zIndex(1) }
            }
                .environmentObject(store)
                .preferredColorScheme(.light)
                .task {
                    store.resume()
                    try? await Task.sleep(for: .milliseconds(850))
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { showsSplash = false }
                }
                .onOpenURL { url in showsSplash = false; store.handleURL(url) }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { store.resume() }
                    else if phase == .background { store.pause() }
                }
        }
    }
}
