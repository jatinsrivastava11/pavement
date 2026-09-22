import Foundation

/// One car model in the catalog, e.g. "Porsche 911". Pavement identifies models, not years or trims.
struct CarModel: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let make: String
    let model: String
    let tier: RarityTier
    let engine: EngineType
    let body: BodyStyle
    /// Rough total production. Only used to sanity-check tiers; often missing.
    let approxBuilt: Int?

    var displayName: String { "\(make) \(model)" }
}

/// The engine a model is best known for. Each type gets one take-apart 3D engine.
enum EngineType: String, Codable, CaseIterable, Sendable {
    case i3, i4, i5, i6, v6, v8, v10, v12, v16, w12, w16, flat4, flat6, rotary, electric

    var displayName: String {
        switch self {
        case .i3, .i4, .i5, .i6: "Inline-\(rawValue.dropFirst())"
        case .v6, .v8, .v10, .v12, .v16, .w12, .w16: rawValue.uppercased()
        case .flat4: "Flat-4"
        case .flat6: "Flat-6"
        case .rotary: "Rotary"
        case .electric: "Electric"
        }
    }
}

/// Body shape. Cars without their own free 3D model use one per body style.
enum BodyStyle: String, Codable, CaseIterable, Sendable {
    case sedan, hatchback, wagon, coupe, convertible, suv, pickup, van, supercar
}
