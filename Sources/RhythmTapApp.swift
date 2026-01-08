import SwiftUI

@main
struct RhythmTapApp: App {
    @State private var isLoadingComplete = false
    
    var body: some Scene {
        WindowGroup {
            if isLoadingComplete {
                ContentView()
            } else {
                LoadingView(isComplete: $isLoadingComplete)
            }
        }
    }
}
