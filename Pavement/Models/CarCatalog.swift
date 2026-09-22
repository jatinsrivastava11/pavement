import Foundation

/// Every car model Pavement knows about, loaded from the bundled `cars.json`.
struct CarCatalog: Sendable {
    let cars: [CarModel]
    private let byID: [String: CarModel]

    init(cars: [CarModel]) {
        self.cars = cars
        byID = Dictionary(cars.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Loads `cars.json` from the app bundle. Built by `Tools/build_cars.py` from `Data/cars/*.tsv`.
    static func bundled(in bundle: Bundle = .main) throws -> CarCatalog {
        guard let url = bundle.url(forResource: "cars", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return CarCatalog(cars: try JSONDecoder().decode([CarModel].self, from: Data(contentsOf: url)))
    }

    func car(id: String) -> CarModel? { byID[id] }

    func cars(in tier: RarityTier) -> [CarModel] { cars.filter { $0.tier == tier } }
}
