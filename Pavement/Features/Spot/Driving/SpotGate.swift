import Foundation

/// Decides whether spotting is allowed right now, based on the trip state and the passenger answer.
///
/// - Not in a vehicle: allowed.
/// - In a moving vehicle: ask "Are you a passenger?" once per trip.
///   - "Passenger" (slide to confirm): allowed for the rest of the trip.
///   - "Driving": blocked until the trip ends.
/// - CarPlay connected during a trip: blocked. That phone is almost always the driver's.
struct SpotGate: Sendable {
    enum Access: Equatable, Sendable {
        case allowed
        case askPassenger
        case blockedDriving
        case blockedCarPlay
    }

    private var trips = TripDetector()
    private var passengerConfirmed = false
    private var driverDeclared = false
    private var carPlayConnected = false

    private(set) var access: Access = .allowed

    init(tripDetector: TripDetector = TripDetector()) {
        trips = tripDetector
    }

    @discardableResult
    mutating func update(_ sample: MotionSample) -> Access {
        let wasInTrip = trips.inTrip
        let inTrip = trips.update(sample)
        carPlayConnected = sample.carPlayConnected
        if wasInTrip && !inTrip {
            // Trip over: the next trip asks again.
            passengerConfirmed = false
            driverDeclared = false
        }
        return recompute()
    }

    /// The person slid to confirm they're a passenger. Only counts during a trip.
    @discardableResult
    mutating func confirmPassenger() -> Access {
        if trips.inTrip && !driverDeclared { passengerConfirmed = true }
        return recompute()
    }

    /// The person said they're driving. Spotting stays blocked until the trip ends.
    @discardableResult
    mutating func declareDriver() -> Access {
        if trips.inTrip {
            driverDeclared = true
            passengerConfirmed = false
        }
        return recompute()
    }

    private mutating func recompute() -> Access {
        access = if !trips.inTrip { .allowed }
            else if carPlayConnected { .blockedCarPlay }
            else if driverDeclared { .blockedDriving }
            else if passengerConfirmed { .allowed }
            else { .askPassenger }
        return access
    }
}
