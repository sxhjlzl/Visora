import Foundation

final class RecentItemsStore {
    private let userDefaults: UserDefaults
    private let key = "recentItems"
    private let maximumItemCount: Int

    init(userDefaults: UserDefaults = .standard, maximumItemCount: Int = 8) {
        self.userDefaults = userDefaults
        self.maximumItemCount = maximumItemCount
    }

    func load() -> [RecentItem] {
        guard let data = userDefaults.data(forKey: key),
              let items = try? JSONDecoder().decode([RecentItem].self, from: data) else {
            return []
        }

        return items
            .sorted { $0.lastOpenedAt > $1.lastOpenedAt }
            .prefix(maximumItemCount)
            .map { $0 }
    }

    func record(url: URL, kind: RecentItem.Kind) -> [RecentItem] {
        let item = RecentItem(url: url, kind: kind, lastOpenedAt: Date())
        let items = ([item] + load().filter { $0.url != url })
            .prefix(maximumItemCount)
            .map { $0 }
        save(items)
        return items
    }

    func remove(url: URL) -> [RecentItem] {
        let items = load().filter { $0.url != url }
        save(items)
        return items
    }

    func clear() {
        userDefaults.removeObject(forKey: key)
    }

    private func save(_ items: [RecentItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        userDefaults.set(data, forKey: key)
    }
}
