import Foundation

/// Use for developer-only logging. No-op in Release; avoids leaking debug info and print overhead.
func debugLog(_ message: String) {
    #if DEBUG
    print(message)
    #endif
}
