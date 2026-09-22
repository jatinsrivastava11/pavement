import Testing
@testable import Pavement

struct RarityTierTests {
    @Test("Ranks map to the agreed top-tier cut-offs", arguments: [
        (1, RarityTier.legendary), (10, .legendary),
        (11, .exotic), (100, .exotic),
        (101, .rare), (250, .rare),
    ])
    func topTierBoundaries(rank: Int, expected: RarityTier) {
        #expect(RarityTier.tier(forRank: rank) == expected)
    }

    @Test("Ranks outside the defined tiers have no tier yet", arguments: [0, -1, 251, 5_000])
    func undefinedRanks(rank: Int) {
        #expect(RarityTier.tier(forRank: rank) == nil)
    }
}
