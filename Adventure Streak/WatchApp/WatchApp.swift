import SwiftUI

#if os(watchOS)
@main
struct Adventure_Streak_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationView {
                WatchContentView()
            }
        }
    }
}
#endif
