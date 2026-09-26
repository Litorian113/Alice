import SwiftUI

@main
struct BobCompanionApp: App {
    @StateObject private var store = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.light)
        }
    }
}
