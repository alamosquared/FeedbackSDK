import FeedbackSDK
import Foundation

enum FeedbackExampleAppSettings {
    private enum Keys {
        static let apiKey = "feedback.sample.apiKey"
        static let baseURL = "feedback.sample.baseURL"
    }

    static let defaultAPIKey = "pk_dev_local"
    static let defaultBaseURL = "http://localhost:8070"

    static var apiKey: String {
        get { UserDefaults.standard.string(forKey: Keys.apiKey) ?? defaultAPIKey }
        set { UserDefaults.standard.set(newValue, forKey: Keys.apiKey) }
    }

    static var baseURLString: String {
        get { UserDefaults.standard.string(forKey: Keys.baseURL) ?? defaultBaseURL }
        set { UserDefaults.standard.set(newValue, forKey: Keys.baseURL) }
    }

    static var baseURL: URL? {
        URL(string: baseURLString)
    }

    static func configureSDK() {
        guard let baseURL else { return }
        FeedbackSDK.configure(
            apiKey: apiKey,
            baseURL: baseURL,
            identityKeySyncPolicy: .userConfigurable(defaultSyncs: true)
        )
    }
}
