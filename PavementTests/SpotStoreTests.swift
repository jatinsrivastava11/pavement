import Foundation
import Testing
@testable import Pavement

@MainActor
struct SpotStoreTests {
    let catalog: CarCatalog
    let dir: URL
    init() throws {
        catalog = try CarCatalog.bundled()
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    func car(_ id: String) throws -> CarModel { try #require(catalog.car(id: id)) }
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    @Test("A spot earns its tier's Octane")
    func earnsTierOctane() throws {
        let store = SpotStore(directory: dir)
        #expect(try store.add(car: car("honda-civic"), at: t0).octane == 10)
        #expect(try store.add(car: car("bugatti-divo"), at: t0).octane == 2_000)
        #expect(store.totalOctane == 2_010)
    }

    @Test("Snapping the same parked car again within 10 minutes earns 0")
    func repeatSameCar() throws {
        let store = SpotStore(directory: dir)
        try store.add(car: car("porsche-911"), at: t0, latitude: 40.0, longitude: -74.0)
        let again = try store.add(car: car("porsche-911"), at: t0 + 60, latitude: 40.0001, longitude: -74.0)
        #expect(again.octane == 0)
    }

    @Test("Same model somewhere else, or much later, earns full Octane")
    func differentPlaceOrTime() throws {
        let store = SpotStore(directory: dir)
        try store.add(car: car("porsche-911"), at: t0, latitude: 40.0, longitude: -74.0)
        #expect(try store.add(car: car("porsche-911"), at: t0 + 60, latitude: 40.01, longitude: -74.0).octane > 0)  // ~1.1 km away
        #expect(try store.add(car: car("porsche-911"), at: t0 + 3_600, latitude: 40.0, longitude: -74.0).octane > 0) // an hour later
    }

    @Test("A different model right next to it earns full Octane")
    func differentModelSamePlace() throws {
        let store = SpotStore(directory: dir)
        try store.add(car: car("porsche-911"), at: t0, latitude: 40.0, longitude: -74.0)
        #expect(try store.add(car: car("honda-civic"), at: t0 + 5, latitude: 40.0, longitude: -74.0).octane == 10)
    }

    @Test("Spots survive restarting the app")
    func persists() throws {
        try SpotStore(directory: dir).add(car: car("toyota-corolla"), at: t0)
        let reopened = SpotStore(directory: dir)
        #expect(reopened.spots.count == 1)
        #expect(reopened.spots.first?.carID == "toyota-corolla")
    }

    @Test("Collection has one entry per model, rarest first")
    func collectionSorted() throws {
        let store = SpotStore(directory: dir)
        try store.add(car: car("honda-civic"), at: t0)
        try store.add(car: car("honda-civic"), at: t0 + 7_200)
        try store.add(car: car("mclaren-f1"), at: t0 + 10)
        try store.add(car: car("porsche-911"), at: t0 + 20)
        let entries = store.collection(catalog: catalog)
        #expect(entries.map(\.car.id) == ["mclaren-f1", "porsche-911", "honda-civic"])
        #expect(entries.last?.timesSpotted == 2)
    }
}
