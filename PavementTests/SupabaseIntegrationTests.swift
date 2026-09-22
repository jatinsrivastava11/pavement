import Foundation
import Auth
import Supabase
import Testing
@testable import Pavement

/// Runs the app's real database code against a local Postgres + PostgREST with the real migrations
/// applied. Off unless the harness provides the connection details:
///
///     Tools/test_app_against_database.sh
///
/// It proves the app's queries match the schema and the security rules, without touching the live
/// Supabase project.
@MainActor
@Suite(.enabled(if: ProcessInfo.processInfo.environment["PAVEMENT_DB_URL"] != nil), .serialized)
struct SupabaseIntegrationTests {
    let catalog: CarCatalog
    let ana: UUID, bo: UUID
    let anaClient: SupabaseClient, boClient: SupabaseClient

    /// Sessions aren't used here (tokens come from the harness), so storage can be a no-op.
    struct NoStorage: AuthLocalStorage {
        func store(key: String, value: Data) throws {}
        func retrieve(key: String) throws -> Data? { nil }
        func remove(key: String) throws {}
    }

    init() throws {
        catalog = try CarCatalog.bundled()
        let env = ProcessInfo.processInfo.environment
        let urlString = try #require(env["PAVEMENT_DB_URL"])
        let url = try #require(URL(string: urlString))
        let anaID = try #require(env["PAVEMENT_ANA_ID"])
        let boID = try #require(env["PAVEMENT_BO_ID"])
        ana = try #require(UUID(uuidString: anaID))
        bo = try #require(UUID(uuidString: boID))
        func client(_ token: String) -> SupabaseClient {
            SupabaseClient(supabaseURL: url, supabaseKey: "local-test",
                           options: .init(auth: .init(storage: NoStorage(), accessToken: { token })))
        }
        anaClient = client(try #require(env["PAVEMENT_ANA_JWT"]))
        boClient = client(try #require(env["PAVEMENT_BO_JWT"]))
    }

    private func store() -> SpotStore {
        SpotStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    }

    /// Rows this test just created, looked up by id so earlier runs don't interfere.
    private struct SpotRow: Decodable { let id: UUID; let car_id: String; let octane: Int; let user_id: UUID }

    private func fetchSpots(_ client: SupabaseClient, ids: [UUID]) async throws -> [SpotRow] {
        try await client.from("spots").select("id, car_id, octane, user_id")
            .in("id", values: ids.map(\.uuidString)).execute().value
    }

    @Test("Spots upload, and the server sets Octane from the car's tier")
    func uploadsSpots() async throws {
        let spots = store()
        // A far-away location each run, so the server's anti-farming rule doesn't zero the Octane.
        let lat = Double.random(in: -60...60), lon = Double.random(in: -170...170)
        try spots.add(car: #require(catalog.car(id: "honda-civic")), latitude: lat, longitude: lon)
        try spots.add(car: #require(catalog.car(id: "mclaren-f1")), latitude: lat, longitude: lon)
        let sync = SpotSync(uploader: SupabaseSpotUploader(client: anaClient),
                            directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        #expect(await sync.syncPending(from: spots) == 2)

        let rows = try await fetchSpots(anaClient, ids: spots.spots.map(\.id))
        #expect(rows.count == 2)
        #expect(rows.first { $0.car_id == "honda-civic" }?.octane == 10)
        #expect(rows.first { $0.car_id == "mclaren-f1" }?.octane == 2_000)
        #expect(rows.allSatisfy { $0.user_id == ana })
    }

    @Test("Uploading the same spot twice doesn't duplicate it")
    func uploadIsIdempotent() async throws {
        let spots = store()
        try spots.add(car: #require(catalog.car(id: "toyota-corolla")))
        let uploader = SupabaseSpotUploader(client: anaClient)
        let spot = try #require(spots.spots.first)
        try await uploader.upload(spot)
        try await uploader.upload(spot)
        #expect(try await fetchSpots(anaClient, ids: [spot.id]).count == 1)
    }

    @Test("Community spot counts come back for the Rankings screen")
    func spotCounts() async throws {
        let spots = store()
        try spots.add(car: #require(catalog.car(id: "porsche-911")))
        let sync = SpotSync(uploader: SupabaseSpotUploader(client: anaClient),
                            directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        await sync.syncPending(from: spots)
        let counts = try await SpotCountService.fetch(client: anaClient)
        #expect(counts.contains { $0.carID == "porsche-911" && $0.spotters == 1 })
        // The ranking puts never-spotted cars first and spotted ones later.
        let ranked = SpotRanking.rank(catalog: catalog, counts: counts)
        #expect(ranked.last?.spotters ?? 0 > 0)
    }

    @Test("Usernames, friend requests and friends-only spots work end to end")
    func friends() async throws {
        let me = ana, them = bo
        let anaService = FriendsService(client: anaClient, currentUserID: { _ in me })
        let boService = FriendsService(client: boClient, currentUserID: { _ in them })
        try await anaService.setUsername("ana_spots")
        try await boService.setUsername("bo_spots")

        let found = try await anaService.find(username: "bo_spots")
        #expect(found?.id == bo)

        // Ana needs at least one spot for the friend-visibility checks below.
        let spots = store()
        try spots.add(car: #require(catalog.car(id: "mclaren-f1")),
                      latitude: Double.random(in: -60...60), longitude: Double.random(in: -170...170))
        let sync = SpotSync(uploader: SupabaseSpotUploader(client: anaClient),
                            directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        await sync.syncPending(from: spots)

        // Start from "not friends" even if an earlier run left a friendship behind.
        try await anaClient.from("friendships").delete().or("requester.eq.\(ana),addressee.eq.\(ana)").execute()
        #expect(try await boService.spots(of: ana).isEmpty, "strangers see no spots")

        try await anaService.sendRequest(to: bo)
        #expect(try await boService.lists().incoming == [ana])
        #expect(try await anaService.lists().outgoing == [bo])

        try await boService.accept(from: ana)
        #expect(try await boService.lists().friends == [ana])
        #expect(try await anaService.lists().friends == [bo])

        // Now Bo can see Ana's spots, and rare finds are filtered to Rare and above.
        let anasSpots = try await boService.spots(of: ana)
        #expect(!anasSpots.isEmpty)
        let rare = try await boService.recentRareFinds(friends: [ana], catalog: catalog)
        #expect(rare.allSatisfy { [.rare, .exotic, .legendary].contains(catalog.car(id: $0.carID)?.tier) })
        #expect(rare.contains { $0.carID == "mclaren-f1" })
    }

    @Test("A user can't write someone else's Octane or spots")
    func cannotCheat() async throws {
        struct ProfileUpdate: Encodable { let octane: Int }
        await #expect(throws: (any Error).self) {
            try await anaClient.from("profiles").update(ProfileUpdate(octane: 999_999)).eq("id", value: ana).execute()
        }
        // Inserting a spot as someone else: the server rewrites it to the caller.
        struct FakeSpot: Encodable { let id: UUID; let car_id: String; let user_id: String }
        let forged = UUID()
        try? await anaClient.from("spots").insert(FakeSpot(id: forged, car_id: "bugatti-divo", user_id: bo.uuidString)).execute()
        let rows = try await fetchSpots(anaClient, ids: [forged])
        #expect(rows.allSatisfy { $0.user_id == ana }, "a forged spot is owned by its sender, never the named user")
    }
}
