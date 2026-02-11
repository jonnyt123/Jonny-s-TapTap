import CoreGraphics
import CoreText
import Foundation
import UIKit

/// Registers custom fonts with the system exactly once per app launch. Use this instead of
/// calling CTFontManagerRegisterGraphicsFont from scenes to avoid duplicate-registration log spam
/// (e.g. "GSFont: 'ApocalypseGrungeAlt' already exists.", GSFontRegisterCGFont failed 305).
enum FontRegistrar {

    private static let lock = NSLock()
    /// Cache: "ResourceName.ext" -> postScriptName. If present we skip registration and return this.
    private static var registered: [String: String] = [:]

    /// Registers the font from the main bundle if not already registered. Returns the postScript
    /// name to use for SKLabelNode/CTFont, or nil if the font could not be loaded.
    /// Call from UI code when you need the font; registration runs at most once per (resourceName, ext).
    static func registerFont(
        resourceName: String,
        fileExtension: String,
        fallbackPostScriptName: String
    ) -> String? {
        let key = "\(resourceName).\(fileExtension)"
        lock.lock()
        if let cached = registered[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        guard let url = Bundle.main.url(forResource: resourceName, withExtension: fileExtension),
              let data = try? Data(contentsOf: url),
              let provider = CGDataProvider(data: data as CFData),
              let cgFont = CGFont(provider) else {
            return nil
        }

        let postScriptName = cgFont.postScriptName as String? ?? fallbackPostScriptName

        lock.lock()
        if let cached = registered[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        var error: Unmanaged<CFError>?
        let ok = CTFontManagerRegisterGraphicsFont(cgFont, &error)
        let alreadyRegistered = (error?.takeRetainedValue()).map { CFErrorGetCode($0) == 305 } ?? false

        lock.lock()
        if ok || alreadyRegistered {
            registered[key] = postScriptName
        }
        let result = registered[key] ?? (ok ? postScriptName : nil)
        lock.unlock()

        return result
    }
}
