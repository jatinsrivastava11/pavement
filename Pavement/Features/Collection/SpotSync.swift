import Foundation
import Supabase

/// Something that can upload a spot record (Supabase in the app, a stand-in in tests).
protocol SpotUploader: Sendable {
    func upload(_ spot: Spot) async throws
}

/// Uploads spots taken on this phone, including ones taken offline, exactly once each.
///
/// Only the record goes up (car, time, location); photos stay on the phone. The server
/// recalculates Octane itself, so the app's number is never trusted.
@MainActor
final class SpotSync {
    private let uploader: any SpotUploader
    private let syncedFile: URL
    private(set) var synced: Set<UUID>
    private var running = false

    init(uploader: any SpotUploader, directory: URL? = nil) {
        self.uploader = uploader
        let dir = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pavement", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        syncedFile = dir.appendingPathComponent("synced-spots.json")
        synced = (try? JSONDecoder().decode(Set<UUID>.self, from: Data(contentsOf: syncedFile))) ?? []
    }

    func pending(in store: SpotStore) -> [Spot] {
        store.spots.filter { !synced.contains($0.id) }.sorted { $0.spottedAt < $1.spottedAt }
    }

    /// Uploads everything not yet uploaded, oldest first. Stops at the first failure (offline, or
    /// the database isn't set up yet) and tries again next time. Returns how many went up.
    @discardableResult
    func syncPending(from store: SpotStore) async -> Int {
        guard !running else { return 0 }
        running = true
        defer { running = false }
        var uploaded = 0
        for spot in pending(in: store) {
            do {
                try await uploader.upload(spot)
            } catch {
                break
            }
            synced.insert(spot.id)
            uploaded += 1
            try? JSONEncoder().encode(synced).write(to: syncedFile, options: .atomic)
        }
        return uploaded
    }
}

/// Uploads to the `spots` table (needs `supabase/migrations/0001`).
struct SupabaseSpotUploader: SpotUploader {
    var client: SupabaseClient = supabase

    struct Row: Encodable {
        let id: UUID
        let car_id: String
        let spotted_at: Date
        let latitude: Double?
        let longitude: Double?
    }

    func upload(_ spot: Spot) async throws {
        let row = Row(id: spot.id, car_id: spot.carID, spotted_at: spot.spottedAt,
                      latitude: spot.latitude, longitude: spot.longitude)
        // Upsert by id, so a retry after a dropped connection can't create a duplicate.
        try await client.from("spots").upsert(row, onConflict: "id", ignoreDuplicates: true).execute()
    }
}
