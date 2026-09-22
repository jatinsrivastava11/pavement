import Foundation
import Testing
@testable import Pavement

struct FriendsTests {
    let me = UUID(), ana = UUID(), bo = UUID(), cy = UUID(), stranger1 = UUID(), stranger2 = UUID()

    @Test("Friendships sort into friends, incoming and outgoing")
    func lists() {
        let rows = [
            FriendshipRow(requester: me, addressee: ana, status: "accepted"),
            FriendshipRow(requester: bo, addressee: me, status: "accepted"),
            FriendshipRow(requester: cy, addressee: me, status: "pending"),
            FriendshipRow(requester: me, addressee: stranger1, status: "pending"),
            FriendshipRow(requester: stranger1, addressee: stranger2, status: "accepted"),   // not mine: ignored
        ]
        let l = FriendLists(rows: rows, me: me)
        #expect(Set(l.friends) == [ana, bo])
        #expect(l.incoming == [cy])
        #expect(l.outgoing == [stranger1])
    }

    @Test("Usernames: 3–20 lowercase letters, numbers, underscores", arguments: [
        ("car_fan", true), ("  Car_Fan  ", true), ("ab", false), (String(repeating: "a", count: 21), false),
        ("car fan", false), ("car-fan", false), ("émile", false), ("r34_gtr", true),
    ])
    func usernames(input: String, valid: Bool) {
        if case .success = Username.validate(input) { #expect(valid) } else { #expect(!valid) }
    }

    @Test("Usernames are lowercased")
    func lowercased() throws {
        #expect(try Username.validate("R34_GTR").get() == "r34_gtr")
    }

    @Test("Rare-find alerts keep only Rare, Exotic and Legendary")
    func rareFinds() throws {
        let catalog = try CarCatalog.bundled()
        let spots = ["honda-civic", "porsche-911", "lamborghini-aventador", "bugatti-chiron", "mclaren-f1", "not-a-car"]
            .map { FriendsService.RemoteSpot(carID: $0, spottedAt: .now, userID: ana) }
        #expect(RareFinds.filter(spots, catalog: catalog).map(\.carID) == ["lamborghini-aventador", "bugatti-chiron", "mclaren-f1"])
    }

    @Test("Profile shows collected / total per tier")
    @MainActor func tierProgress() throws {
        let catalog = try CarCatalog.bundled()
        let store = SpotStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        try store.add(car: #require(catalog.car(id: "honda-civic")))
        try store.add(car: #require(catalog.car(id: "mclaren-f1")))
        let rows = ProfileStats.tierProgress(collection: store.collection(catalog: catalog), catalog: catalog)
        #expect(rows.first { $0.tier == .legendary }?.collected == 1)
        #expect(rows.first { $0.tier == .legendary }?.total == 10)
        #expect(rows.first { $0.tier == .common }?.collected == 1)
        #expect(rows.map(\.total).reduce(0, +) == catalog.cars.count)
    }
}
