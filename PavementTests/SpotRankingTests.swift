import Foundation
import Testing
@testable import Pavement

struct SpotRankingTests {
    let catalog = CarCatalog(cars: [
        CarModel(id: "a-civic", make: "Honda", model: "Civic", tier: .common, engine: .i4, body: .sedan, approxBuilt: nil),
        CarModel(id: "b-911", make: "Porsche", model: "911", tier: .occasional, engine: .flat6, body: .coupe, approxBuilt: nil),
        CarModel(id: "c-f1", make: "McLaren", model: "F1", tier: .legendary, engine: .v12, body: .supercar, approxBuilt: 106),
        CarModel(id: "d-corolla", make: "Toyota", model: "Corolla", tier: .common, engine: .i4, body: .sedan, approxBuilt: nil),
    ])

    @Test("Fewest spotters first; never-spotted cars lead, rarer tier breaks ties")
    func order() {
        let counts = [SpotCount(carID: "a-civic", spotters: 50, spots: 90),
                      SpotCount(carID: "b-911", spotters: 3, spots: 4),
                      SpotCount(carID: "d-corolla", spotters: 50, spots: 60)]
        let ranked = SpotRanking.rank(catalog: catalog, counts: counts).map(\.car.id)
        // F1: 0 spotters. 911: 3. Corolla and Civic tie at 50 spotters; Corolla has fewer spots.
        #expect(ranked == ["c-f1", "b-911", "d-corolla", "a-civic"])
    }

    @Test("Counts for cars not in the catalog are ignored")
    func unknownCars() {
        let ranked = SpotRanking.rank(catalog: catalog, counts: [SpotCount(carID: "zz-unknown", spotters: 1, spots: 1)])
        #expect(ranked.count == 4)
    }

    @Test("Decodes the database's snake_case columns")
    func decodes() throws {
        let json = #"[{"car_id":"b-911","spotters":3,"spots":4}]"#.data(using: .utf8)!
        let counts = try JSONDecoder().decode([SpotCount].self, from: json)
        #expect(counts == [SpotCount(carID: "b-911", spotters: 3, spots: 4)])
    }
}
