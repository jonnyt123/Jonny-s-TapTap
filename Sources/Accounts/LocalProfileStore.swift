import Foundation

final class LocalProfileStore: ProfileStore {
    private let storageKey: String

    init(storageKey: String) {
        self.storageKey = storageKey
    }

    func load() async -> AccountState? {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(AccountState.self, from: data)
    }

    func save(_ state: AccountState) async {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(state) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
