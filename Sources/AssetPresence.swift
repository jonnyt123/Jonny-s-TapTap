import SwiftUI
import UIKit

enum AssetPresence {
    private static var loggedMissing: Set<String> = []

    /// Returns true if the named image exists in the asset catalog. Logs once per missing name (debug).
    static func hasImageAsset(_ name: String) -> Bool {
        let exists = UIImage(named: name) != nil
        if !exists {
            if !loggedMissing.contains(name) {
                loggedMissing.insert(name)
                debugLog("Missing asset: \(name)")
            }
        }
        return exists
    }

    static func exists(_ name: String) -> Bool {
        hasImageAsset(name)
    }
}
