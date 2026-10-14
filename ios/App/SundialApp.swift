import Features
import SwiftUI

/// The composition root (architecture §3): builds the concrete Data types and injects them into Features.
@main
struct SundialApp: App {
    private let config = AppConfig.current

    var body: some Scene {
        WindowGroup {
            PlaceholderView(
                appName: config.displayName,
                backendEnvironment: config.backendEnvironment.rawValue
            )
        }
    }
}
