import Foundation

/// One car the user spotted. The photo stays on the phone; only this record is synced.
struct Spot: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    let carID: String
    let spottedAt: Date
    let latitude: Double?
    let longitude: Double?
    /// Octane actually awarded (0 if it was a repeat of the same parked car).
    let octane: Int
    /// File name of the cropped photo in the app's local storage, if saved.
    var photoFile: String?
}
