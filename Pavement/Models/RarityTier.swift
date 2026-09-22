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

    /// Returns the tier for a car's position in the world rarity ranking (1 = rarest).
    ///
    /// Only the top three tiers have agreed cut-offs so far. Niche, Occasional and Common
    /// thresholds are still undecided, so ranks past 250 return `nil` for now.
    static func tier(forRank rank: Int) -> RarityTier? {
        switch rank {
        case 1...10: .legendary
        case 11...100: .exotic
        case 101...250: .rare
        default: nil
        }
    }
}
