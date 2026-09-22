import CoreLocation
import Foundation

/// How much Octane a spot earns.
///
/// Every spot earns its tier's Octane, except re-spotting the same model in the same place within a
/// short time (standing next to one parked car and snapping it over and over), which earns 0.
enum OctaneRules {
    static let repeatWindow: TimeInterval = 10 * 60
    static let repeatDistance: CLLocationDistance = 200

    static func octane(for car: CarModel, at time: Date, latitude: Double?, longitude: Double?,
                       previous: [Spot]) -> Int {
        let isRepeat = previous.contains { spot in
            guard spot.carID == car.id, abs(time.timeIntervalSince(spot.spottedAt)) < repeatWindow else { return false }
            // Without a location on either spot, a quick repeat of the same model counts as the same car.
            guard let lat = latitude, let lon = longitude, let pLat = spot.latitude, let pLon = spot.longitude else { return true }
            return CLLocation(latitude: lat, longitude: lon)
                .distance(from: CLLocation(latitude: pLat, longitude: pLon)) < repeatDistance
        }
        return isRepeat ? 0 : car.tier.octane
    }
}
