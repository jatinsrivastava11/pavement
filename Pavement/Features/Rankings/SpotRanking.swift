import Foundation
import Supabase

/// How many people have spotted each car, from the community database.
struct SpotCount: Codable, Hashable, Sendable {
    let carID: String
    let spotters: Int
    let spots: Int

    enum CodingKeys: String, CodingKey {
        case carID = "car_id", spotters, spots
    }
}

enum SpotRanking {
    /// Rarest-to-find first: fewest people who've spotted it, then fewest spots. Cars nobody has
    /// spotted yet come first; ties break by production tier (rarer first), then name.
    static func rank(catalog: CarCatalog, counts: [SpotCount]) -> [(car: CarModel, spotters: Int)] {
        let byID = Dictionary(counts.map { ($0.carID, $0) }, uniquingKeysWith: { a, _ in a })
        let tierOrder = Dictionary(uniqueKeysWithValues: RarityTier.allCases.enumerated().map { ($1, $0) })
        return catalog.cars
            .map { car in (car: car, count: byID[car.id]) }
            .sorted { a, b in
                let (sa, sb) = (a.count?.spotters ?? 0, b.count?.spotters ?? 0)
                if sa != sb { return sa < sb }
                let (pa, pb) = (a.count?.spots ?? 0, b.count?.spots ?? 0)
                if pa != pb { return pa < pb }
                if a.car.tier != b.car.tier { return tierOrder[a.car.tier]! < tierOrder[b.car.tier]! }
                return a.car.displayName < b.car.displayName
            }
            .map { (car: $0.car, spotters: $0.count?.spotters ?? 0) }
    }
}

/// Loads community spot counts. Needs the database migration in `supabase/migrations`.
enum SpotCountService {
    static func fetch(client: SupabaseClient = supabase) async throws -> [SpotCount] {
        try await client.rpc("car_spot_counts").execute().value
    }
}
