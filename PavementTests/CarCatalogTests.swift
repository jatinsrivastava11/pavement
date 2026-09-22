import Foundation
import Testing
@testable import Pavement

struct CarCatalogTests {
    let catalog: CarCatalog
    init() throws { catalog = try CarCatalog.bundled() }

    private func tier(_ make: String, _ model: String) -> RarityTier? {
        catalog.cars.first { $0.make == make && $0.model == model }?.tier
    }

    @Test("Catalog loads and every id is unique")
    func loads() {
        #expect(catalog.cars.count > 200)
        #expect(Set(catalog.cars.map(\.id)).count == catalog.cars.count)
    }

    @Test("Top tiers are roughly the agreed sizes: ~10 / ~90 / ~150")
    func tierSizes() {
        #expect((8...15).contains(catalog.cars(in: .legendary).count))
        #expect((70...120).contains(catalog.cars(in: .exotic).count))
        #expect((110...200).contains(catalog.cars(in: .rare).count))
    }

    @Test("Every tier below Rare has plenty of cars")
    func lowerTierSizes() {
        #expect(catalog.cars(in: .niche).count >= 150)
        #expect(catalog.cars(in: .occasional).count >= 200)
        #expect(catalog.cars(in: .common).count >= 150)
    }

    // MARK: Anchors: placements that must never be wrong.

    @Test("Every Bugatti is Legendary or Exotic; the rarest ones are Legendary")
    func bugattis() {
        let bugattis = catalog.cars.filter { $0.make == "Bugatti" }
        #expect(!bugattis.isEmpty)
        for car in bugattis {
            #expect([.legendary, .exotic].contains(car.tier), "\(car.displayName) is \(car.tier)")
        }
        for model in ["La Voiture Noire", "Centodieci", "Divo", "Bolide"] {
            #expect(tier("Bugatti", model) == .legendary, "Bugatti \(model)")
        }
        #expect(tier("Bugatti", "Chiron") == .exotic)
        #expect(tier("Bugatti", "Veyron") == .exotic)
    }

    @Test("Famous hypercars are Legendary or Exotic", arguments: [
        ("McLaren", "F1"), ("Ferrari", "250 GTO"), ("Ferrari", "LaFerrari"), ("Ferrari", "Enzo"),
        ("Porsche", "918 Spyder"), ("McLaren", "P1"), ("Pagani", "Zonda"), ("Koenigsegg", "Jesko"),
        ("Lamborghini", "Veneno"), ("Aston Martin", "Valkyrie"), ("Lexus", "LFA"),
    ])
    func hypercars(make: String, model: String) {
        let t = tier(make, model)
        #expect(t == .legendary || t == .exotic, "\(make) \(model) is \(String(describing: t))")
    }

    @Test("Everyday cars are never in the top three tiers", arguments: [
        ("Honda", "Civic"), ("Honda", "Accord"), ("Toyota", "Corolla"), ("Toyota", "Camry"),
        ("Volkswagen", "Tiguan"), ("Volkswagen", "Golf"), ("Ford", "F-150"), ("Ford", "Mustang"),
        ("Tesla", "Model 3"), ("Tesla", "Model Y"), ("Porsche", "911"), ("Mercedes-Benz", "G-Class"),
        ("Chevrolet", "Corvette"), ("BMW", "3 Series"), ("Nissan", "GT-R"),
    ])
    func everydayCars(make: String, model: String) {
        let t = tier(make, model)
        #expect(t == nil || ![.legendary, .exotic, .rare].contains(t!), "\(make) \(model) is \(String(describing: t))")
    }

    @Test("Best-sellers are Common", arguments: [
        ("Honda", "Civic"), ("Honda", "Accord"), ("Honda", "CR-V"), ("Toyota", "Corolla"),
        ("Toyota", "Camry"), ("Toyota", "RAV4"), ("Volkswagen", "Tiguan"), ("Volkswagen", "Golf"),
        ("Ford", "F-150"), ("Ford", "Mustang"), ("Tesla", "Model 3"), ("Tesla", "Model Y"),
        ("BMW", "3 Series"), ("Chevrolet", "Silverado"), ("Hyundai", "Elantra"), ("Nissan", "Altima"),
    ])
    func bestSellers(make: String, model: String) {
        #expect(tier(make, model) == .common, "\(make) \(model)")
    }

    @Test("Well-known middle cases land where expected", arguments: [
        ("Porsche", "911", RarityTier.occasional), ("Mercedes-Benz", "G-Class", .occasional),
        ("Chevrolet", "Corvette", .occasional), ("Nissan", "GT-R", .niche),
        ("Lamborghini", "Huracán", .niche), ("Ferrari", "458 Italia", .niche),
        ("Rolls-Royce", "Cullinan", .niche), ("Dodge", "Viper", .niche),
    ])
    func middleCases(make: String, model: String, expected: RarityTier) {
        #expect(tier(make, model) == expected, "\(make) \(model)")
    }

    @Test("Supercar brands never fall to Occasional or Common")
    func supercarBrandsStayRare() {
        let brands: Set = ["Ferrari", "Lamborghini", "McLaren", "Bugatti", "Pagani", "Koenigsegg", "Rolls-Royce", "Bentley"]
        for car in catalog.cars where brands.contains(car.make) {
            #expect(![.occasional, .common].contains(car.tier), "\(car.displayName) is \(car.tier)")
        }
    }

    // MARK: Consistency with rough production numbers.

    /// Each production range allows two neighbouring tiers, so placement can be fuzzy but never wild.
    static func allowedTiers(forBuilt built: Int) -> Set<RarityTier> {
        switch built {
        case ...150: [.legendary, .exotic]
        case 151...1_500: [.exotic, .rare]
        case 1_501...20_000: [.rare, .niche]
        case 20_001...200_000: [.niche, .occasional]
        case 200_001...2_000_000: [.occasional, .common]
        default: [.common]
        }
    }

    @Test("Tiers agree with rough production numbers (within one tier)")
    func productionConsistency() {
        let mismatches = catalog.cars.compactMap { car -> String? in
            guard let built = car.approxBuilt, !Self.allowedTiers(forBuilt: built).contains(car.tier) else { return nil }
            return "\(car.displayName): \(car.tier) but ~\(built) built"
        }
        #expect(mismatches.isEmpty, "\(mismatches.count) mismatches:\n\(mismatches.joined(separator: "\n"))")
    }

    @Test("Every Legendary, Exotic and Rare car has a rough production number")
    func topTiersHaveNumbers() {
        let missing = catalog.cars.filter { [.legendary, .exotic, .rare].contains($0.tier) && $0.approxBuilt == nil }
        #expect(missing.isEmpty, "\(missing.map(\.displayName))")
    }

    // MARK: Engine types.

    @Test("Engine anchors")
    func engines() {
        for car in catalog.cars where car.make == "Bugatti" && car.model != "Tourbillon" && car.model != "EB110" {
            #expect(car.engine == .w16, "\(car.displayName)")
        }
        for car in catalog.cars where ["Rimac", "Pininfarina"].contains(car.make) {
            #expect(car.engine == .electric, "\(car.displayName)")
        }
        for car in catalog.cars where car.make == "Koenigsegg" {
            #expect(car.engine == .v8, "\(car.displayName)")
        }
        for car in catalog.cars where car.make == "Porsche" && car.model.hasPrefix("911") && car.model != "911 GT1 Strassenversion" {
            #expect(car.engine == .flat6, "\(car.displayName)")
        }
    }
}
