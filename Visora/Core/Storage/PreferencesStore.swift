import Foundation

final class PreferencesStore {
    private let userDefaults: UserDefaults
    private let key = "appSettings"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() -> AppSettings {
        guard let data = userDefaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .defaults
        }
        return settings.normalized
    }

    func save(_ settings: AppSettings) {
        let normalized = settings.normalized
        guard let data = try? JSONEncoder().encode(normalized) else { return }
        userDefaults.set(data, forKey: key)
    }
}
