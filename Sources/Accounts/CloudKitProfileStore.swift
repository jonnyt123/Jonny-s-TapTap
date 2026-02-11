import Foundation
import CloudKit

final class CloudKitProfileStore: ProfileStore {
    private let database: CKDatabase
    private let recordID: CKRecord.ID

    init(userId: String, container: CKContainer = CKContainer.default()) {
        self.database = container.privateCloudDatabase
        self.recordID = CKRecord.ID(recordName: "AccountState_\(userId)")
    }

    func load() async -> AccountState? {
        do {
            let record = try await database.record(for: recordID)
            return AccountState.from(record: record)
        } catch {
            return nil
        }
    }

    func save(_ state: AccountState) async {
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch {
            record = CKRecord(recordType: "AccountState", recordID: recordID)
        }

        AccountState.apply(state, to: record)

        do {
            _ = try await database.save(record)
        } catch let ckError as CKError where ckError.code == .serverRecordChanged {
            if let serverRecord = ckError.serverRecord {
                AccountState.apply(state, to: serverRecord)
                do {
                    _ = try await database.save(serverRecord)
                } catch {
                    debugLog("Cloud save failed after conflict retry: \(error)")
                }
            } else {
                debugLog("Cloud save failed: \(ckError)")
            }
        } catch {
            debugLog("Cloud save failed: \(error)")
        }
    }
}

private extension AccountState {
    static func apply(_ state: AccountState, to record: CKRecord) {
        record["userId"] = state.userId as CKRecordValue
        if let username = state.username, !username.isEmpty {
            record["username"] = username as CKRecordValue
        }
        record["level"] = state.level as CKRecordValue
        record["xpTotal"] = state.xpTotal as CKRecordValue
        record["coinsBalance"] = state.coinsBalance as CKRecordValue
        record["ownedSongIds"] = Array(state.ownedSongIds) as CKRecordValue
        record["createdAt"] = state.createdAt as CKRecordValue
        record["updatedAt"] = state.updatedAt as CKRecordValue
        record["schemaVersion"] = state.schemaVersion as CKRecordValue
    }

    static func from(record: CKRecord) -> AccountState? {
        guard let userId = record["userId"] as? String else { return nil }
        let level = record["level"] as? Int ?? 1
        let username = record["username"] as? String
        let xpTotal = record["xpTotal"] as? Int64 ?? 0
        let coinsBalance = record["coinsBalance"] as? Int ?? 0
        let owned = record["ownedSongIds"] as? [String] ?? []
        // Treat missing timestamps as OLD, not "now".
        let createdAt = (record["createdAt"] as? Date)
            ?? record.creationDate
            ?? .distantPast

        let updatedAt = (record["updatedAt"] as? Date)
            ?? record.modificationDate
            ?? .distantPast
        let schemaVersion = record["schemaVersion"] as? Int ?? AccountState.schemaVersionCurrent
        return AccountState(
            userId: userId,
            username: username,
            level: level,
            xpTotal: xpTotal,
            coinsBalance: coinsBalance,
            ownedSongIds: Set(owned),
            createdAt: createdAt,
            updatedAt: updatedAt,
            schemaVersion: schemaVersion
        )
    }
}
