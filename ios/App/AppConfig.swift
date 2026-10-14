import Foundation

/// The settings-file keys (docs/06-environments-and-release.md §2), read from Info.plist.
/// This is the only place in the app that reads them.
struct AppConfig {
    enum BackendEnvironment: String {
        case local = "Local"
        case dev = "Dev"
        case prod = "Prod"
    }

    let displayName: String
    let appGroupID: String
    let supabaseURL: String
    let supabasePublishableKey: String
    let powerSyncURL: String
    let backendEnvironment: BackendEnvironment

    static let current = AppConfig(bundle: .main)

    init(bundle: Bundle) {
        func value(_ key: String) -> String {
            bundle.object(forInfoDictionaryKey: key) as? String ?? ""
        }
        guard let backendEnvironment = BackendEnvironment(rawValue: value("BACKEND_ENV")) else {
            preconditionFailure("BACKEND_ENV is missing or unknown: check the build's settings file")
        }
        displayName = value("CFBundleDisplayName")
        appGroupID = value("APP_GROUP_ID")
        supabaseURL = value("SUPABASE_URL")
        supabasePublishableKey = value("SUPABASE_PUBLISHABLE_KEY")
        powerSyncURL = value("POWERSYNC_URL")
        self.backendEnvironment = backendEnvironment
    }
}
