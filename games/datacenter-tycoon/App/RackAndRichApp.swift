import SwiftUI

@main struct RackAndRichApp: App {
    @StateObject private var store = GameStore()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(store)
                .tint(Theme.teal)
                .preferredColorScheme(.light)
                .task { store.activate() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { store.activate() } else { store.deactivate() }
                }
        }
    }
}
