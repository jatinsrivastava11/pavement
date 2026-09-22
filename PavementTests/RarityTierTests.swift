import Testing
@testable import Pavement

struct RarityTierTests {
    @Test("Ranks map to the agreed tier cut-offs", arguments: [
        (1, RarityTier.legendary), (10, .legendary),
        (11, .exotic), (100, .exotic),
        (101, .rare), (250, .rare),
        (251, .niche), (750, .niche),
        (751, .occasional), (1_500, .occasional),
        (1_501, .common), (100_000, .common),
    ])
    func tierBoundaries(rank: Int, expected: RarityTier) {
        #expect(RarityTier.tier(forRank: rank) == expected)
    }

    @Test("Invalid ranks have no tier", arguments: [0, -1])
    func invalidRanks(rank: Int) {
        #expect(RarityTier.tier(forRank: rank) == nil)
    }

    @Test("Octane rewards match the agreed values")
    func octaneValues() {
        #expect(RarityTier.legendary.octane == 2_000)
        #expect(RarityTier.exotic.octane == 500)
        #expect(RarityTier.rare.octane == 200)
        #expect(RarityTier.niche.octane == 75)
        #expect(RarityTier.occasional.octane == 25)
        #expect(RarityTier.common.octane == 10)
    }

    @Test("Rarer tiers always give more Octane")
    func octaneIncreasesWithRarity() {
        // allCases runs rarest to most common, so rewards must strictly decrease.
        let rewards = RarityTier.allCases.map(\.octane)
        #expect(zip(rewards, rewards.dropFirst()).allSatisfy { $0 > $1 })
    }
}
