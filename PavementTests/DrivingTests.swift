import Foundation
import Testing
@testable import Pavement

/// Builds a timeline of sensor samples, one every `step` seconds.
private struct Timeline {
    var now = Date(timeIntervalSince1970: 0)
    var samples: [MotionSample] = []

    mutating func add(for seconds: TimeInterval, step: TimeInterval = 5,
                      activity: MotionSample.Activity?, speed: Double?, accuracy: Double? = 1,
                      carPlay: Bool = false) {
        var elapsed: TimeInterval = 0
        while elapsed < seconds {
            samples.append(MotionSample(time: now, activity: activity, speed: speed,
                                        speedAccuracy: accuracy, carPlayConnected: carPlay))
            now += step
            elapsed += step
        }
    }
}

private extension SpotGate {
    mutating func run(_ timeline: Timeline) -> Access {
        for sample in timeline.samples { update(sample) }
        return access
    }
}

struct TripDetectorTests {
    @Test("Walking is not a trip")
    func walking() {
        var detector = TripDetector()
        var t = Timeline()
        t.add(for: 120, activity: .walking, speed: 1.4)
        #expect(!t.samples.map { detector.update($0) }.contains(true))
    }

    @Test("Fast cycling is not a trip")
    func cycling() {
        var detector = TripDetector()
        var t = Timeline()
        t.add(for: 120, activity: .cycling, speed: 8)
        #expect(!t.samples.map { detector.update($0) }.contains(true))
    }

    @Test("Highway speed is a trip even if the motion sensor is unsure")
    func highwaySpeed() {
        var detector = TripDetector()
        var t = Timeline()
        t.add(for: 30, activity: .unknown, speed: 28)
        #expect(t.samples.map { detector.update($0) }.last == true)
    }

    @Test("Motion sensor alone (no GPS) can start a trip")
    func motionOnly() {
        var detector = TripDetector()
        var t = Timeline()
        t.add(for: 30, activity: .automotive(.high), speed: nil, accuracy: nil)
        #expect(t.samples.map { detector.update($0) }.last == true)
    }

    @Test("GPS alone (no motion sensor, like the simulator) can start a trip")
    func gpsOnly() {
        var detector = TripDetector()
        var t = Timeline()
        t.add(for: 30, activity: nil, speed: 15)
        #expect(t.samples.map { detector.update($0) }.last == true)
    }

    @Test("Unknown GPS accuracy still counts at clearly-car speed (the simulator reports -1)")
    func unknownAccuracyHighSpeed() {
        var detector = TripDetector()
        var t = Timeline()
        t.add(for: 30, activity: nil, speed: 25, accuracy: -1)
        #expect(t.samples.map { detector.update($0) }.last == true)
    }

    @Test("Unknown GPS accuracy at jogging-to-cycling speed doesn't start a trip")
    func unknownAccuracyLowSpeed() {
        var detector = TripDetector()
        var t = Timeline()
        t.add(for: 60, activity: nil, speed: 8, accuracy: -1)
        #expect(!t.samples.map { detector.update($0) }.contains(true))
    }

    @Test("Inaccurate GPS speed is ignored")
    func badGPS() {
        var detector = TripDetector()
        var t = Timeline()
        t.add(for: 60, activity: .stationary, speed: 30, accuracy: 40)
        #expect(!t.samples.map { detector.update($0) }.contains(true))
    }

    @Test("Low-confidence 'automotive' at walking speed is not a trip")
    func lowConfidence() {
        var detector = TripDetector()
        var t = Timeline()
        t.add(for: 60, activity: .automotive(.low), speed: 1)
        #expect(!t.samples.map { detector.update($0) }.contains(true))
    }
}

struct SpotGateTests {
    @Test("Not moving: spotting allowed")
    func parked() {
        var gate = SpotGate()
        var t = Timeline()
        t.add(for: 60, activity: .stationary, speed: 0)
        #expect(gate.run(t) == .allowed)
    }

    @Test("Moving car: asks if you're a passenger")
    func asks() {
        var gate = SpotGate()
        var t = Timeline()
        t.add(for: 30, activity: .automotive(.high), speed: 15)
        #expect(gate.run(t) == .askPassenger)
    }

    @Test("Passenger stays allowed through a red light")
    func passengerThroughRedLight() {
        var gate = SpotGate()
        var t = Timeline()
        t.add(for: 30, activity: .automotive(.high), speed: 15)
        _ = gate.run(t)
        #expect(gate.confirmPassenger() == .allowed)

        var rest = Timeline(now: t.now)
        rest.add(for: 60, activity: .stationary, speed: 0)          // red light
        rest.add(for: 60, activity: .automotive(.high), speed: 14)   // driving again
        #expect(gate.run(rest) == .allowed)
    }

    @Test("Passenger answer resets after the trip; the next trip asks again")
    func nextTripAsksAgain() {
        var gate = SpotGate()
        var t = Timeline()
        t.add(for: 30, activity: .automotive(.high), speed: 15)
        _ = gate.run(t)
        gate.confirmPassenger()

        var later = Timeline(now: t.now)
        later.add(for: 20, activity: .walking, speed: 1.2)           // got out
        #expect(gate.run(later) == .allowed)

        var nextTrip = Timeline(now: later.now)
        nextTrip.add(for: 30, activity: .automotive(.high), speed: 20)
        #expect(gate.run(nextTrip) == .askPassenger)
    }

    @Test("Driver is blocked for the whole trip, including stops shorter than 3 minutes")
    func driverBlocked() {
        var gate = SpotGate()
        var t = Timeline()
        t.add(for: 30, activity: .automotive(.high), speed: 15)
        _ = gate.run(t)
        #expect(gate.declareDriver() == .blockedDriving)
        // Can't switch to passenger mid-trip after saying you're driving.
        #expect(gate.confirmPassenger() == .blockedDriving)

        var rest = Timeline(now: t.now)
        rest.add(for: 120, activity: .stationary, speed: 0)
        #expect(gate.run(rest) == .blockedDriving)
    }

    @Test("Driver unlocks once the car has been stopped for 3 minutes")
    func driverUnlocksAfterStop() {
        var gate = SpotGate()
        var t = Timeline()
        t.add(for: 30, activity: .automotive(.high), speed: 15)
        _ = gate.run(t)
        gate.declareDriver()

        var parked = Timeline(now: t.now)
        parked.add(for: 190, activity: .stationary, speed: 0)
        #expect(gate.run(parked) == .allowed)
    }

    @Test("CarPlay while moving blocks, even for a confirmed passenger")
    func carPlayBlocks() {
        var gate = SpotGate()
        var t = Timeline()
        t.add(for: 30, activity: .automotive(.high), speed: 15)
        _ = gate.run(t)
        gate.confirmPassenger()

        var withCarPlay = Timeline(now: t.now)
        withCarPlay.add(for: 10, activity: .automotive(.high), speed: 15, carPlay: true)
        #expect(gate.run(withCarPlay) == .blockedCarPlay)
    }

    @Test("CarPlay while parked doesn't block")
    func carPlayParked() {
        var gate = SpotGate()
        var t = Timeline()
        t.add(for: 60, activity: .stationary, speed: 0, carPlay: true)
        #expect(gate.run(t) == .allowed)
    }

    @Test("Answering outside a trip does nothing")
    func answersOutsideTripIgnored() {
        var gate = SpotGate()
        #expect(gate.confirmPassenger() == .allowed)
        #expect(gate.declareDriver() == .allowed)
        var t = Timeline()
        t.add(for: 30, activity: .automotive(.high), speed: 15)
        #expect(gate.run(t) == .askPassenger)
    }
}
