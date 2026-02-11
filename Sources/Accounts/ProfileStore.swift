import Foundation

protocol ProfileStore {
    func load() async -> AccountState?
    func save(_ state: AccountState) async
}
