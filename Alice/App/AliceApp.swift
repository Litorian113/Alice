import SwiftUI

@main
struct AliceApp: App {
    @StateObject private var store = AliceSessionStore()

    var body: some Scene {
        WindowGroup {
            AliceRootView()
                .environmentObject(store)
                .preferredColorScheme(.light)
        }
    }
}
