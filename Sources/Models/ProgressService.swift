import Foundation
import CloudKit

struct ProgressData {
    let tapCoins: Int
    let unlockedSongIDs: Set<String>
    let lastUpdated: Date
}

final class ProgressService {
    static let shared = ProgressService()
    private let container = CKContainer.default()
    private var database: CKDatabase { container.privateCloudDatabase }
    private let recordID = CKRecord.ID(recordName: "UserProgress")
    private let defaultUnlocked: Set<String> = ["hallelujah"]
    
    func fetch() async -> ProgressData? {
        do {
            let record = try await database.record(for: recordID)
            let coins = record["tapCoins"] as? Int ?? 0
            let ids = record["unlockedSongIDs"] as? [String] ?? Array(defaultUnlocked)
            let updated = record["lastUpdated"] as? Date ?? Date()
            return ProgressData(tapCoins: coins, unlockedSongIDs: Set(ids).union(defaultUnlocked), lastUpdated: updated)
        } catch {
            // If not found, return nil; we'll create on save
            return nil
        }
    }
    
    func save(tapCoins: Int, unlockedSongIDs: Set<String>) async {
        do {
            let record: CKRecord
            do {
                record = try await database.record(for: recordID)
            } catch {
                record = CKRecord(recordType: "UserProgress", recordID: recordID)
            }
            record["tapCoins"] = tapCoins
            record["unlockedSongIDs"] = Array(unlockedSongIDs)
            record["lastUpdated"] = Date()
            _ = try await database.save(record)
        } catch {
            // Silently ignore for now; app remains functional offline
            print("Cloud save failed: \(error)")
        }
    }
    
    func loadAndMerge(into gameState: GameState) async {
        guard let cloud = await fetch() else { return }
        await MainActor.run {
            gameState.tapCoins = cloud.tapCoins
            gameState.unlockedSongIDs = cloud.unlockedSongIDs
            gameState.saveProgressLocal()
        }
    }
}
