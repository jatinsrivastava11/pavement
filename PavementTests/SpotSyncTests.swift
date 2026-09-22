import Foundation
import Testing
@testable import Pavement

/// A stand-in server that records uploads and can be switched offline.
private actor FakeServer: SpotUploader {
    var received: [UUID] = []
    var offline = false
    var failAfter: Int?
    func setOffline(_ v: Bool) { offline = v }
    func setFailAfter(_ n: Int?) { failAfter = n }
    func upload(_ spot: Spot) async throws {
        if offline { throw URLError(.notConnectedToInternet) }
        if let n = failAfter, received.count >= n { throw URLError(.timedOut) }
        received.append(spot.id)
    }
}

@MainActor
struct SpotSyncTests {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let catalog: CarCatalog
    init() throws { catalog = try CarCatalog.bundled() }

    private func store(_ n: Int) throws -> SpotStore {
        let s = SpotStore(directory: dir)
        for i in 0..<n { try s.add(car: #require(catalog.car(id: "honda-civic")), at: Date(timeIntervalSince1970: Double(i) * 3_600)) }
        return s
    }

    @Test("Uploads every spot once, oldest first")
    func uploadsOnce() async throws {
        let server = FakeServer(), s = try store(3)
        let sync = SpotSync(uploader: server, directory: dir)
        #expect(await sync.syncPending(from: s) == 3)
        #expect(await sync.syncPending(from: s) == 0)
        #expect(await server.received == s.spots.sorted { $0.spottedAt < $1.spottedAt }.map(\.id))
    }

    @Test("Offline: nothing is lost; it all goes up once back online")
    func offlineThenOnline() async throws {
        let server = FakeServer(), s = try store(2)
        await server.setOffline(true)
        let sync = SpotSync(uploader: server, directory: dir)
        #expect(await sync.syncPending(from: s) == 0)
        #expect(sync.pending(in: s).count == 2)
        await server.setOffline(false)
        #expect(await sync.syncPending(from: s) == 2)
        #expect(sync.pending(in: s).isEmpty)
    }

    @Test("A failure halfway keeps the rest pending, and nothing is uploaded twice")
    func partialFailure() async throws {
        let server = FakeServer(), s = try store(4)
        await server.setFailAfter(2)
        let sync = SpotSync(uploader: server, directory: dir)
        #expect(await sync.syncPending(from: s) == 2)
        await server.setFailAfter(nil)
        #expect(await sync.syncPending(from: s) == 2)
        #expect(Set(await server.received).count == 4)
        #expect(await server.received.count == 4)
    }

    @Test("What's been uploaded survives restarting the app")
    func remembersAcrossRestart() async throws {
        let server = FakeServer(), s = try store(2)
        await SpotSync(uploader: server, directory: dir).syncPending(from: s)
        let reopened = SpotSync(uploader: server, directory: dir)
        #expect(reopened.pending(in: s).isEmpty)
    }

    @Test("Uploaded rows never include photos, only the record")
    func noPhotos() throws {
        let row = SupabaseSpotUploader.Row(id: UUID(), car_id: "honda-civic", spotted_at: .now, latitude: 1, longitude: 2)
        let json = try String(decoding: JSONEncoder().encode(row), as: UTF8.self)
        #expect(!json.contains("photo") && !json.contains("octane"))
    }
}
