import SwiftUI

@main
struct RhythmTapApp: App {
    @State private var isLoadingComplete = false
    
    var body: some Scene {
        WindowGroup {
            if isLoadingComplete {
                ContentView()
                    .onAppear {
                        GameCenterManager.shared.authenticateIfNeeded()
                    }
            } else {
                LoadingView(isComplete: $isLoadingComplete)
                    .onAppear {
                        GameCenterManager.shared.authenticateIfNeeded()
                    }
            }
        }
    }
}
