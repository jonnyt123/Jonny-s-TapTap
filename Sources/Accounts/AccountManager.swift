import Foundation
import AuthenticationServices
import Combine
import CloudKit

@MainActor
final class AccountManager: NSObject, ObservableObject {
    static let shared = AccountManager()

    @Published private(set) var state: AccountState
    @Published private(set) var isSignedIn: Bool = false
    @Published private(set) var statusText: String = "Guest"
    @Published var requiresUsername: Bool = false
    @Published var lastErrorMessage: String?

    private let keychainService = "com.jonny.taptap.account"
    private let keychainAccount = "appleUserId"
    private let guestStorageKey = "account.guest.profile"
    private let starterSongs: Set<String> = ["hallelujah"]

    private var activeStore: ProfileStore
    private var lastSaveTask: Task<Void, Never>?

    private override init() {
        let guestStore = LocalProfileStore(storageKey: guestStorageKey)
        self.activeStore = guestStore
        self.state = AccountState.newGuest(starterSongs: starterSongs)
        super.init()
    }

    func loadOnLaunch() {
        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            if let storedUserId = KeychainHelper.read(service: self.keychainService, account: self.keychainAccount) {
                let provider = ASAuthorizationAppleIDProvider()
                let credentialState = try? await provider.credentialState(forUserID: storedUserId)
                if credentialState == .authorized {
                    await self.switchToSignedIn(userId: storedUserId)
                    return
                } else {
                    KeychainHelper.delete(service: self.keychainService, account: self.keychainAccount)
                }
            }
            await self.switchToGuest()
        }
    }

    func handleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            let userId = credential.user
            KeychainHelper.save(userId, service: keychainService, account: keychainAccount)
            Task { await switchToSignedIn(userId: userId) }
        case .failure(let error):
            debugLog("Sign in failed: \(error)")
        }
    }

    func signOut() {
        KeychainHelper.delete(service: keychainService, account: keychainAccount)
        Task { await switchToGuest() }
    }

    func claimUsername(_ rawValue: String) async throws {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = normalizedUsername(trimmed)
        try validateUsername(trimmed)

        guard isSignedIn else {
            throw UsernameClaimError.notSignedIn
        }

        try await claimUsernameInCloud(normalized: normalized)

        state.username = trimmed
        bumpUpdatedAt()
        persist()
        requiresUsername = false
    }

    func applyXP(result: SongResult) -> LevelUpResult {
        let thresholds = LevelingCurve.defaultThresholds
        let output = LevelingSystem.awardXP(result: result, totalXP: state.xpTotal, thresholds: thresholds)
        state.xpTotal = output.totalXP
        state.level = output.newLevel
        bumpUpdatedAt()
        persist()
        return output
    }

    /// Add Tap Coins (e.g. from playing). Never reduces balance; ignores negative amounts.
    func addCoins(_ amount: Int) {
        let safeAmount = max(0, amount)
        state.coinsBalance = max(0, state.coinsBalance + safeAmount)
        bumpUpdatedAt()
        persist()
    }

    /// Purchase a song with Tap Coins. Prevents double purchase and negative balance.
    @discardableResult
    func purchaseSong(songId: String, price: Int) -> Bool {
        guard price > 0 else { return false }
        guard !state.ownedSongIds.contains(songId) else { return false }
        guard state.coinsBalance >= price else { return false }
        state.coinsBalance = max(0, state.coinsBalance - price)
        state.ownedSongIds.insert(songId)
        bumpUpdatedAt()
        persist()
        return true
    }

    func resetCurrentAccount() {
        if isSignedIn {
            let existingUsername = state.username
            state = AccountState.newSignedIn(userId: state.userId, starterSongs: starterSongs)
            state.username = existingUsername
        } else {
            state = AccountState.newGuest(starterSongs: starterSongs)
        }
        requiresUsername = isSignedIn && (state.username?.isEmpty ?? true)
        persist()
    }

    func persistCurrentState() {
        persist()
    }

    private func switchToGuest() async {
        activeStore = LocalProfileStore(storageKey: guestStorageKey)
        if let loaded = await activeStore.load() {
            if state.userId == loaded.userId {
                if shouldApplyLoadedState(loaded) || (isDefaultLike(state) && !isDefaultLike(loaded)) {
                    state = loaded
                } else {
                    persist()
                }
            } else {
                state = loaded
            }
        } else {
            state = AccountState.newGuest(starterSongs: starterSongs)
            await activeStore.save(state)
        }
        isSignedIn = false
        statusText = "Guest"
        requiresUsername = false
    }

    private func switchToSignedIn(userId: String) async {
        activeStore = CloudKitProfileStore(userId: userId)
        if let loaded = await activeStore.load() {
            if state.userId == loaded.userId {
                if shouldApplyLoadedState(loaded) || (isDefaultLike(state) && !isDefaultLike(loaded)) {
                    state = loaded
                } else {
                    persist()
                }
            } else {
                state = loaded
            }
        } else {
            state = AccountState.newSignedIn(userId: userId, starterSongs: starterSongs)
            await activeStore.save(state)
        }
        isSignedIn = true
        statusText = "Signed in"
        requiresUsername = false
        scheduleUsernameRecheck()
    }

    private func persist() {
        let snapshot = state
        let store = activeStore

        lastSaveTask?.cancel()
        lastSaveTask = Task(priority: .background) {
            await store.save(snapshot)
        }
    }

    private func scheduleUsernameRecheck() {
        Task.detached(priority: .background) { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            await self?.refreshSignedInProfile()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.requiresUsername = self.isSignedIn && ((self.state.username?.isEmpty) ?? true)
            }
        }
    }

    private func refreshSignedInProfile() async {
        guard isSignedIn, let cloudStore = activeStore as? CloudKitProfileStore else { return }

        // Ensure latest save finishes before reading back, to avoid stale round-trips.
        if let task = lastSaveTask { _ = await task.value }

        if let loaded = await cloudStore.load() {
            if shouldApplyLoadedState(loaded) {
                state = loaded
            } else {
                #if DEBUG
                debugLog("⚠️ Ignored stale/default cloud state. local(lvl=\(state.level), coins=\(state.coinsBalance), xp=\(state.xpTotal), updated=\(state.updatedAt)) cloud(lvl=\(loaded.level), coins=\(loaded.coinsBalance), xp=\(loaded.xpTotal), updated=\(loaded.updatedAt))")
                #endif
            }
        }
    }

    private func bumpUpdatedAt() {
        state.updatedAt = Date()
    }

    private func isDefaultLike(_ s: AccountState) -> Bool {
        s.level <= 1 && s.xpTotal == 0 && s.coinsBalance == 0
    }

    private func shouldApplyLoadedState(_ loaded: AccountState) -> Bool {
        // Identity guard: never apply a different user's state over current signed-in identity.
        if isSignedIn, let currentId = state.userId as String?, currentId != loaded.userId { return false }

        // Hard rule: updatedAt cannot go backwards.
        if loaded.updatedAt < state.updatedAt { return false }

        // Safety rules: prevent obvious progress regression.
        if loaded.xpTotal < state.xpTotal { return false }
        if loaded.level < state.level { return false }

        // Coins can go down ONLY if a spend happened; stale snapshot going to 0 is never valid.
        if loaded.coinsBalance < state.coinsBalance && loaded.updatedAt <= state.updatedAt { return false }

        // Block "default-like" cloud snapshots from overwriting non-default local.
        if isDefaultLike(loaded) && !isDefaultLike(state) { return false }

        return true
    }

    private func normalizedUsername(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func validateUsername(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < 3 || trimmed.count > 16 {
            throw UsernameClaimError.invalid
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        if trimmed.rangeOfCharacter(from: allowed.inverted) != nil {
            throw UsernameClaimError.invalid
        }
    }

    private func claimUsernameInCloud(normalized: String) async throws {
        let publicDB = CKContainer.default().publicCloudDatabase
        let recordID = CKRecord.ID(recordName: normalized)
        let record = CKRecord(recordType: "Username", recordID: recordID)
        record["userId"] = state.userId as NSString
        record["createdAt"] = Date() as NSDate

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let op = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
            op.savePolicy = .allKeys
            op.isAtomic = true
            op.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: ())
                case .failure(let error):
                    if let ck = error as? CKError {
                        if ck.code == .serverRecordChanged || ck.code == .constraintViolation {
                            continuation.resume(throwing: UsernameClaimError.duplicate)
                            return
                        }
                        if ck.code == .batchRequestFailed, let partial = ck.partialErrorsByItemID {
                            let hasDuplicate = partial.values.contains { inner in
                                if let innerCK = inner as? CKError {
                                    return innerCK.code == .serverRecordChanged || innerCK.code == .constraintViolation
                                }
                                return false
                            }
                            if hasDuplicate {
                                continuation.resume(throwing: UsernameClaimError.duplicate)
                                return
                            }
                        }
                        continuation.resume(throwing: UsernameClaimError.cloud(ck))
                        return
                    }
                    continuation.resume(throwing: UsernameClaimError.cloud(error))
                }
            }
            publicDB.add(op)
        }
    }
}

enum UsernameClaimError: Error {
    case invalid
    case duplicate
    case notSignedIn
    case cloud(Error)
}
