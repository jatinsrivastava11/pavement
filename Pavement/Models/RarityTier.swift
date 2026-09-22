import Foundation

/// How rare a car model is, from most to least rare.
enum RarityTier: String, CaseIterable, Codable, Sendable {
    case legendary
    case exotic
    case rare
    case niche
    case occasional
    case common

    var displayName: String { rawValue.capitalized }

    /// Octane awarded for spotting a car in this tier.
    var octane: Int {
        switch self {
        case .legendary: 2_000
        case .exotic: 500
        case .rare: 200
        case .niche: 75
        case .occasional: 25
        case .common: 10
        }
    }

    /// Returns the tier for a car's position in the world rarity ranking (1 = rarest).
    /// Ranks below 1 are invalid and return `nil`.
    static func tier(forRank rank: Int) -> RarityTier? {
        switch rank {
        case 1...10: .legendary
        case 11...100: .exotic
        case 101...250: .rare
        case 251...750: .niche
        case 751...1_500: .occasional
        case 1_501...: .common
        default: nil
        }
    }
}
