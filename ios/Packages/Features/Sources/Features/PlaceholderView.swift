import Domain
import SwiftUI

/// P0 placeholder: shows which variant and backend this build is. Replaced by Today in P1.
public struct PlaceholderView: View {
    private let appName: String
    private let backendEnvironment: String

    public init(appName: String, backendEnvironment: String) {
        self.appName = appName
        self.backendEnvironment = backendEnvironment
    }

    public var body: some View {
        VStack(spacing: 8) {
            Text(appName)
                .font(.largeTitle.bold())
            Text("Backend: \(backendEnvironment)")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
