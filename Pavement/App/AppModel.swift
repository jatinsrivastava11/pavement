import Foundation
import Observation

/// Shared app state: the car catalog and the user's spots.
@MainActor
@Observable
final class AppModel {
    let catalog: CarCatalog
    let spots: SpotStore
    let photos: SpotPhotoStore

    init(catalog: CarCatalog? = nil, spots: SpotStore? = nil, photos: SpotPhotoStore? = nil) {
        self.catalog = catalog ?? ((try? CarCatalog.bundled()) ?? CarCatalog(cars: []))
        self.spots = spots ?? SpotStore()
        self.photos = photos ?? SpotPhotoStore()
    }

    #if DEBUG
    /// A throwaway model with sample spots, for previews and screenshots. Never touches real data.
    static func demo() -> AppModel {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pavement-demo-\(UUID().uuidString)")
        let model = AppModel(spots: SpotStore(directory: dir), photos: SpotPhotoStore(directory: dir))
        let ids = ["bugatti-chiron", "porsche-911", "honda-civic", "lamborghini-huracan", "ford-mustang",
                   "nissan-gt-r", "mercedes-benz-g-class", "tesla-model-y", "ferrari-f40", "toyota-corolla", "honda-civic"]
        for (i, id) in ids.enumerated() {
            if let car = model.catalog.car(id: id) {
                _ = try? model.spots.add(car: car, at: .now.addingTimeInterval(Double(-i) * 86_400))
            }
        }
        return model
    }
    #endif
}
