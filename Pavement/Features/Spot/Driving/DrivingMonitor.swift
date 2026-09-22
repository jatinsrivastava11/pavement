@preconcurrency import AVFoundation
import CoreLocation
import CoreMotion
import Observation
import os

/// Feeds live motion, GPS and CarPlay readings into a `SpotGate` while the Spot screen is open.
@MainActor
@Observable
final class DrivingMonitor: NSObject {
    private(set) var access: SpotGate.Access = .allowed
    /// Latest location, saved with each spot later on.
    private(set) var lastLocation: CLLocation?

    @ObservationIgnored private var gate = SpotGate()
    @ObservationIgnored private let motion = CMMotionActivityManager()
    @ObservationIgnored private let location = CLLocationManager()
    @ObservationIgnored private var latestActivity: MotionSample.Activity?
    @ObservationIgnored private var heartbeat: Task<Void, Never>?

    override init() {
        super.init()
        location.delegate = self
        location.desiredAccuracy = kCLLocationAccuracyBest
        location.activityType = .otherNavigation
    }

    func start() {
        if location.authorizationStatus == .notDetermined { location.requestWhenInUseAuthorization() }
        location.startUpdatingLocation()

        if CMMotionActivityManager.isActivityAvailable() {
            motion.startActivityUpdates(to: .main) { [weak self] activity in
                guard let activity else { return }
                let mapped = Self.map(activity)
                MainActor.assumeIsolated {
                    self?.latestActivity = mapped
                    self?.evaluate()
                }
            }
        }

        // Re-check regularly so trips can end even when no new readings arrive.
        heartbeat?.cancel()
        heartbeat = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                self?.evaluate()
            }
        }
        evaluate()
    }

    func stop() {
        location.stopUpdatingLocation()
        motion.stopActivityUpdates()
        heartbeat?.cancel()
        heartbeat = nil
    }

    func confirmPassenger() { access = gate.confirmPassenger() }
    func declareDriver() { access = gate.declareDriver() }

    private func evaluate() {
        let sample = MotionSample(
            time: .now,
            activity: latestActivity,
            speed: freshLocation?.speed,
            speedAccuracy: freshLocation?.speedAccuracy,
            carPlayConnected: Self.isCarPlayConnected
        )
        access = gate.update(sample)
        Self.log.debug("sample speed=\(sample.speed ?? -99, privacy: .public) acc=\(sample.speedAccuracy ?? -99, privacy: .public) access=\(String(describing: self.access), privacy: .public)")
    }

    private static let log = Logger(subsystem: "com.jatinsrivastava.pavement", category: "driving")

    /// Ignores GPS readings older than 30 s, so a stale highway speed can't keep a trip alive.
    private var freshLocation: CLLocation? {
        guard let lastLocation, Date.now.timeIntervalSince(lastLocation.timestamp) < 30 else { return nil }
        return lastLocation
    }

    private static var isCarPlayConnected: Bool {
        AVAudioSession.sharedInstance().currentRoute.outputs.contains { $0.portType == .carAudio }
    }

    nonisolated private static func map(_ a: CMMotionActivity) -> MotionSample.Activity {
        let confidence: MotionSample.Confidence = switch a.confidence {
        case .high: .high
        case .medium: .medium
        default: .low
        }
        if a.automotive { return .automotive(confidence) }
        if a.cycling { return .cycling }
        if a.running { return .running }
        if a.walking { return .walking }
        if a.stationary { return .stationary }
        return .unknown
    }
}

extension DrivingMonitor: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newest = locations.last else { return }
        Task { @MainActor in
            self.lastLocation = newest
            self.evaluate()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {}
}
