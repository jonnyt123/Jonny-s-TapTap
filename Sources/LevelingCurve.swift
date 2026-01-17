import Foundation

enum LevelingCurve {
    static let maxLevel = 99
    static let maxXP: Int64 = 13_000_000
    static let defaultThresholds = LevelingCurve.powerCurve(exponent: 2.2)

    enum CurveOption {
        case power(exponent: Double)
        case runelike
    }

    static func thresholds(for option: CurveOption) -> [Int64] {
        switch option {
        case .power(let exponent):
            return powerCurve(exponent: exponent)
        case .runelike:
            return runelikeCurve()
        }
    }

    static func powerCurve(exponent: Double) -> [Int64] {
        var thresholds = Array(repeating: Int64(0), count: maxLevel + 1)
        thresholds[1] = 0
        for level in 2...maxLevel {
            let t = Double(level - 1) / Double(maxLevel - 1)
            let xp = Double(maxXP) * pow(t, exponent)
            let rounded = Int64(xp.rounded())
            thresholds[level] = max(thresholds[level - 1], rounded)
        }
        thresholds[maxLevel] = maxXP
        return thresholds
    }

    static func runelikeCurve() -> [Int64] {
        var raw: [Int64] = Array(repeating: 0, count: maxLevel + 1)
        var points: Double = 0
        raw[1] = 0
        for level in 2...maxLevel {
            let l = Double(level - 1)
            points += floor(l + 300.0 * pow(2.0, l / 7.0))
            let xp = floor(points / 4.0)
            raw[level] = Int64(xp)
        }
        let scale = Double(maxXP) / max(Double(raw[maxLevel]), 1.0)
        var thresholds = Array(repeating: Int64(0), count: maxLevel + 1)
        thresholds[1] = 0
        for level in 2...maxLevel {
            let scaled = Int64((Double(raw[level]) * scale).rounded())
            thresholds[level] = max(thresholds[level - 1], scaled)
        }
        thresholds[maxLevel] = maxXP
        return thresholds
    }
}
