import Foundation

/// One reading from the phone's sensors.
struct MotionSample: Sendable {
    enum Activity: Sendable, Equatable {
        case stationary, walking, running, cycling
        case automotive(Confidence)
        case unknown
    }

    enum Confidence: Int, Sendable, Comparable {
        case low, medium, high
        static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
    }

    var time: Date
    /// From Core Motion. `nil` on devices without motion activity (e.g. the simulator).
    var activity: Activity?
    /// GPS speed in m/s. `nil` or negative means unknown.
    var speed: Double?
    /// GPS speed accuracy in m/s. `nil` or negative means unknown.
    var speedAccuracy: Double?
    var carPlayConnected: Bool = false
}

/// Works out whether the phone is currently on a trip in a vehicle.
///
/// A trip starts on strong evidence of driving speed. Brief stops such as red lights don't end it.
/// It ends when the person starts walking, or after a few minutes with no sign of driving.
struct TripDetector: Sendable {
    /// ~25 km/h. Faster than walking or running; cycling is excluded separately.
    var vehicleSpeed: Double = 7
    /// ~43 km/h. Too fast for a bicycle, whatever the motion sensor says.
    var definitelyVehicleSpeed: Double = 12
    /// GPS speeds less accurate than this are ignored.
    var maxSpeedAccuracy: Double = 5
    /// How long without any sign of driving before a trip counts as over.
    var stopDuration: TimeInterval = 180

    private(set) var inTrip = false
    private var lastVehicleEvidence: Date?

    /// Feeds one sample in. Returns whether a trip is in progress afterwards.
    @discardableResult
    mutating func update(_ sample: MotionSample) -> Bool {
        if hasVehicleEvidence(sample) {
            inTrip = true
            lastVehicleEvidence = sample.time
        } else if inTrip {
            let gotOut = sample.activity == .walking || sample.activity == .running
            let stoppedLongEnough = lastVehicleEvidence.map { sample.time.timeIntervalSince($0) >= stopDuration } ?? true
            if gotOut || stoppedLongEnough {
                inTrip = false
                lastVehicleEvidence = nil
            }
        }
        return inTrip
    }

    private func hasVehicleEvidence(_ sample: MotionSample) -> Bool {
        if case .automotive(let confidence) = sample.activity, confidence >= .medium { return true }
        guard let speed = sample.speed, speed >= 0 else { return false }
        // Accuracy can be unknown (-1), on the simulator and sometimes on real iPhones. Then only
        // clearly-car speeds count; readings known to be inaccurate never count.
        let accuracy = sample.speedAccuracy ?? -1
        if accuracy > maxSpeedAccuracy { return false }
        if speed >= definitelyVehicleSpeed { return true }
        return accuracy >= 0 && speed >= vehicleSpeed && sample.activity != .cycling
    }
}
