import Foundation
import Observation

/// The user's spots, saved on the phone. Works offline; syncing to Supabase comes later.
@MainActor
@Observable
final class SpotStore {
    private(set) var spots: [Spot] = []
    private let fileURL: URL

    /// - Parameter directory: where to keep `spots.json`. Defaults to Application Support.
    init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pavement", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("spots.json")
        if let data = try? Data(contentsOf: fileURL) {
            spots = (try? Self.decoder.decode([Spot].self, from: data)) ?? []
        }
    }

    var totalOctane: Int { spots.reduce(0) { $0 + $1.octane } }

    /// Adds a spot for `car`, working out its Octane. Returns the saved spot.
    @discardableResult
    func add(car: CarModel, at time: Date = .now, latitude: Double? = nil, longitude: Double? = nil,
             photoFile: String? = nil) throws -> Spot {
        let octane = OctaneRules.octane(for: car, at: time, latitude: latitude, longitude: longitude, previous: spots)
        let spot = Spot(carID: car.id, spottedAt: time, latitude: latitude, longitude: longitude,
                        octane: octane, photoFile: photoFile)
        spots.append(spot)
        try save()
        return spot
    }

    /// One entry per car model the user has spotted, rarest first, then most recently spotted.
    func collection(catalog: CarCatalog) -> [CollectionEntry] {
        let grouped = Dictionary(grouping: spots, by: \.carID)
        return grouped.compactMap { id, spots -> CollectionEntry? in
            guard let car = catalog.car(id: id) else { return nil }
            return CollectionEntry(car: car, spots: spots.sorted { $0.spottedAt > $1.spottedAt })
        }
        .sorted {
            let a = RarityTier.allCases.firstIndex(of: $0.car.tier)!, b = RarityTier.allCases.firstIndex(of: $1.car.tier)!
            return a != b ? a < b : $0.lastSpotted > $1.lastSpotted
        }
    }

    /// Deletes every spot on this phone.
    func removeAll() throws {
        spots = []
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func save() throws {
        try Self.encoder.encode(spots).write(to: fileURL, options: .atomic)
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }()
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }()
}

/// A car model in the user's collection, with every time they've spotted it.
struct CollectionEntry: Identifiable, Hashable, Sendable {
    let car: CarModel
    let spots: [Spot]
    var id: String { car.id }
    var timesSpotted: Int { spots.count }
    var lastSpotted: Date { spots.first?.spottedAt ?? .distantPast }
    var totalOctane: Int { spots.reduce(0) { $0 + $1.octane } }
}
