import Foundation

enum InstallIdStorage {
    private static let userDefaultsKey = "feedback:installId"

    private static var cached: String?

    static func current() -> String {
        if let cached {
            return cached
        }

        if let stored = UserDefaults.standard.string(forKey: userDefaultsKey),
           !stored.isEmpty,
           UUID(uuidString: stored) != nil
        {
            cached = stored
            return stored
        }

        let id = UUID().uuidString
        persist(id)
        return id
    }

    private static func persist(_ id: String) {
        cached = id
        UserDefaults.standard.set(id, forKey: userDefaultsKey)
    }
}
