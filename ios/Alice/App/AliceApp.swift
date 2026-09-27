import SwiftUI

@main
struct AliceApp: App {
    @StateObject private var store = AliceSessionStore()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsSplash = true
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                AliceRootView()
                    .allowsHitTesting(!showsSplash)
                    .accessibilityHidden(showsSplash)
                if showsSplash { AliceSplashView().transition(.opacity).zIndex(1) }
            }
                .environmentObject(store)
                .preferredColorScheme(showsSplash ? .light : (darkModeEnabled ? .dark : .light))
                .task {
                    store.resume()
                    guard showsSplash else { return }
                    do { try await Task.sleep(for: .seconds(2.6)) }
                    catch { return }
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
