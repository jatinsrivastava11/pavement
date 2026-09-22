import Foundation
import simd

/// A 3D engine built from simple shapes, laid out correctly for each engine type.
///
/// Coordinates (meters, roughly real scale): x runs along the crankshaft (front at −x),
/// y is up, z is sideways. Every part has an assembled position and an "exploded" position
/// pushed out along its own direction, so the engine can be pulled apart.
struct EngineBlueprint: Sendable {
    enum Shape: Sendable, Equatable {
        case box(SIMD3<Float>)
        /// Cylinder with its axis along the part's `axis` direction.
        case cylinder(height: Float, radius: Float)
    }

    enum Material: Sendable {
        case block, head, moving, manifold, exhaust, electrical, cover
    }

    struct Part: Identifiable, Sendable {
        let id: String
        let name: String
        let about: String
        let shape: Shape
        let material: Material
        let position: SIMD3<Float>
        /// Unit direction the cylinder axis (or box "up") points along.
        let axis: SIMD3<Float>
        let explodedPosition: SIMD3<Float>
    }

    let engine: EngineType
    let parts: [Part]
    /// Plain-English summary of how this layout works.
    let summary: String

    init(engine: EngineType) {
        self.engine = engine
        switch engine {
        case .electric:
            parts = Self.electricMotor()
            summary = "An electric motor has no pistons or fuel. Magnets and coils spin a rotor directly, which is why EVs are quiet and pull instantly."
        case .rotary:
            parts = Self.rotary()
            summary = "A rotary (Wankel) engine spins triangular rotors inside an oval housing instead of pumping pistons up and down. Compact, smooth and very rev-happy."
        default:
            let layout = Layout(engine)!
            parts = Self.pistonEngine(layout)
            summary = layout.summary
        }
    }

    // MARK: - Piston engines

    struct Layout: Sendable {
        let cylinders: Int
        /// Angle of each bank from vertical, in degrees (0 = straight up).
        let bankAngles: [Float]
        let name: String

        var cylindersPerBank: Int { cylinders / bankAngles.count }

        init?(_ engine: EngineType) {
            switch engine {
            case .i3: (cylinders, bankAngles, name) = (3, [0], "inline-3")
            case .i4: (cylinders, bankAngles, name) = (4, [0], "inline-4")
            case .i5: (cylinders, bankAngles, name) = (5, [0], "inline-5")
            case .i6: (cylinders, bankAngles, name) = (6, [0], "inline-6")
            case .v6: (cylinders, bankAngles, name) = (6, [-30, 30], "V6")
            case .v8: (cylinders, bankAngles, name) = (8, [-45, 45], "V8")
            case .v10: (cylinders, bankAngles, name) = (10, [-45, 45], "V10")
            case .v12: (cylinders, bankAngles, name) = (12, [-32.5, 32.5], "V12")
            case .v16: (cylinders, bankAngles, name) = (16, [-45, 45], "V16")
            case .flat4: (cylinders, bankAngles, name) = (4, [-90, 90], "flat-4")
            case .flat6: (cylinders, bankAngles, name) = (6, [-90, 90], "flat-6")
            case .w12: (cylinders, bankAngles, name) = (12, [-52, -38, 38, 52], "W12")
            case .w16: (cylinders, bankAngles, name) = (16, [-52, -38, 38, 52], "W16")
            case .electric, .rotary: return nil
            }
        }

        var summary: String {
            let banks = bankAngles.count
            switch banks {
            case 1: return "An \(name) has \(cylinders) cylinders standing in one straight row above the crankshaft. Simple, compact and the most common layout in the world."
            case 2 where abs(bankAngles[0]) == 90:
                return "A \(name) (boxer) lays its \(cylinders) cylinders flat in two opposing rows. The pistons punch outward like boxers, which keeps the engine low and smooth."
            case 2:
                return "A \(name) splits its \(cylinders) cylinders into two rows set \(Int(bankAngles[1] - bankAngles[0]))° apart in a V, sharing one crankshaft. Shorter than an inline engine with the same cylinder count."
            default:
                return "A \(name) is two narrow V engines joined on one crankshaft: four rows of \(cylindersPerBank) cylinders. It packs huge power into a short engine."
            }
        }
    }

    private static let spacing: Float = 0.1          // distance between cylinders along the crank
    private static let bore: Float = 0.042           // piston radius
    private static let deckHeight: Float = 0.22      // crank centre to top of the block

    static func pistonEngine(_ layout: Layout) -> [Part] {
        let perBank = layout.cylindersPerBank
        let length = Float(perBank) * spacing + 0.06
        let firstX = -Float(perBank - 1) * spacing / 2
        var parts: [Part] = []

        // Bottom end: crankshaft, block, oil pan.
        parts.append(Part(id: "crankshaft", name: "Crankshaft",
                          about: "Turns the pistons' up-and-down pushes into spinning motion that drives the wheels.",
                          shape: .cylinder(height: length + 0.14, radius: 0.025), material: .moving,
                          position: .zero, axis: [1, 0, 0], explodedPosition: .zero))
        let wide = layout.bankAngles.contains { abs($0) > 60 }
        let blockSize: SIMD3<Float> = wide ? [length, 0.18, 0.26] : [length, 0.2, 0.2]
        parts.append(Part(id: "block", name: "Engine block",
                          about: "The heavy metal core. It holds the cylinders and the crankshaft and keeps everything lined up.",
                          shape: .box(blockSize), material: .block,
                          position: [0, 0.03, 0], axis: [0, 1, 0], explodedPosition: [0, 0.03, 0]))
        parts.append(Part(id: "oil-pan", name: "Oil pan",
                          about: "The tray under the engine that holds the oil, which is pumped around to keep moving parts from wearing out.",
                          shape: .box([length, 0.06, 0.16]), material: .cover,
                          position: [0, -0.12, 0], axis: [0, 1, 0], explodedPosition: [0, -0.42, 0]))

        // Each bank: pistons, then a cylinder head on top, and an exhaust manifold on the outside.
        for (b, angle) in layout.bankAngles.enumerated() {
            let a = angle * .pi / 180
            let dir = SIMD3<Float>(0, cos(a), sin(a))               // bank direction
            let outward = SIMD3<Float>(0, 0, angle == 0 ? 1 : (angle > 0 ? 1 : -1))
            let bankLabel = layout.bankAngles.count == 1 ? "" : " (bank \(b + 1))"
            for c in 0..<perBank {
                let n = b * perBank + c + 1
                let x = firstX + Float(c) * spacing
                let pos = SIMD3<Float>(x, 0, 0) + dir * 0.13
                parts.append(Part(id: "piston-\(n)", name: "Piston \(n)",
                                  about: "Fuel and air burn above the piston and shove it down. That push is where the engine's power comes from.",
                                  shape: .cylinder(height: 0.07, radius: bore), material: .moving,
                                  position: pos, axis: dir, explodedPosition: pos + dir * 0.28))
                let plugPos = SIMD3<Float>(x, 0, 0) + dir * (deckHeight + 0.09)
                parts.append(Part(id: "spark-plug-\(n)", name: "Spark plug \(n)",
                                  about: "Makes the tiny spark that lights the fuel and air in the cylinder, thousands of times a minute.",
                                  shape: .cylinder(height: 0.05, radius: 0.008), material: .electrical,
                                  position: plugPos, axis: dir, explodedPosition: plugPos + dir * 0.55))
            }
            let headPos = dir * (deckHeight + 0.03)
            parts.append(Part(id: "head-\(b + 1)", name: "Cylinder head\(bankLabel)",
                              about: "Caps the top of the cylinders. Its valves open to let air in and burnt gas out at exactly the right moment.",
                              shape: .box([length, 0.06, 0.16]), material: .head,
                              position: headPos, axis: dir, explodedPosition: headPos + dir * 0.4))
            let exhaustPos = headPos + outward * 0.11 - dir * 0.02
            parts.append(Part(id: "exhaust-\(b + 1)", name: "Exhaust manifold\(bankLabel)",
                              about: "Collects the hot burnt gases from each cylinder and sends them to the exhaust pipe.",
                              shape: .box([length, 0.04, 0.04]), material: .exhaust,
                              position: exhaustPos, axis: dir, explodedPosition: exhaustPos + outward * 0.3))
        }

        // Top: intake manifold (between the banks, or on top for inline engines).
        let intakeY: Float = layout.bankAngles.count == 1 ? deckHeight + 0.12 : (wide ? 0.14 : deckHeight + 0.02)
        let intakeZ: Float = layout.bankAngles.count == 1 ? -0.1 : 0
        parts.append(Part(id: "intake", name: "Intake manifold",
                          about: "The pipes that share fresh air out evenly to every cylinder.",
                          shape: .box([length * 0.9, 0.05, 0.08]), material: .manifold,
                          position: [0, intakeY, intakeZ], axis: [0, 1, 0], explodedPosition: [0, intakeY + 0.45, intakeZ]))

        // Ends: timing cover at the front, flywheel at the back.
        parts.append(Part(id: "timing-cover", name: "Timing cover",
                          about: "Covers the belt or chain that keeps the valves opening in step with the pistons.",
                          shape: .box([0.03, 0.26, 0.2]), material: .cover,
                          position: [-length / 2 - 0.02, 0.06, 0], axis: [1, 0, 0], explodedPosition: [-length / 2 - 0.32, 0.06, 0]))
        parts.append(Part(id: "flywheel", name: "Flywheel",
                          about: "A heavy spinning disc that smooths out the pulses from each cylinder and connects to the gearbox.",
                          shape: .cylinder(height: 0.025, radius: 0.13), material: .moving,
                          position: [length / 2 + 0.05, 0, 0], axis: [1, 0, 0], explodedPosition: [length / 2 + 0.35, 0, 0]))
        return parts
    }

    // MARK: - Rotary and electric

    static func rotary() -> [Part] {
        var parts: [Part] = [
            Part(id: "eccentric-shaft", name: "Eccentric shaft",
                 about: "The rotary engine's crankshaft. The rotors spin around off-centre lobes on it, turning it three times per rotor turn.",
                 shape: .cylinder(height: 0.4, radius: 0.02), material: .moving,
                 position: .zero, axis: [1, 0, 0], explodedPosition: .zero),
        ]
        for i in 0..<2 {
            let x: Float = i == 0 ? -0.06 : 0.06
            parts.append(Part(id: "housing-\(i + 1)", name: "Rotor housing \(i + 1)",
                              about: "The oval (epitrochoid) chamber the rotor spins in. Its shape creates the intake, squeeze, burn and exhaust zones.",
                              shape: .cylinder(height: 0.07, radius: 0.15), material: .block,
                              position: [x, 0, 0], axis: [1, 0, 0], explodedPosition: [x * 5, 0, 0]))
            parts.append(Part(id: "rotor-\(i + 1)", name: "Rotor \(i + 1)",
                              about: "The triangular rotor. Each of its three faces does the job a piston does, so it makes power three times per turn.",
                              shape: .cylinder(height: 0.06, radius: 0.1), material: .moving,
                              position: [x, 0, 0], axis: [1, 0, 0], explodedPosition: [x * 5, 0.3, 0]))
        }
        parts.append(Part(id: "intake", name: "Intake manifold",
                          about: "Feeds fresh air into the housings through side ports, with no valves needed.",
                          shape: .box([0.2, 0.05, 0.08]), material: .manifold,
                          position: [0, 0.2, 0], axis: [0, 1, 0], explodedPosition: [0, 0.55, 0]))
        parts.append(Part(id: "exhaust-1", name: "Exhaust manifold",
                          about: "Carries burnt gases out of the housings.",
                          shape: .box([0.2, 0.04, 0.04]), material: .exhaust,
                          position: [0, -0.05, 0.18], axis: [0, 1, 0], explodedPosition: [0, -0.05, 0.5]))
        return parts
    }

    static func electricMotor() -> [Part] {
        [
            Part(id: "shaft", name: "Output shaft",
                 about: "Spins with the rotor and sends the motor's power to the wheels through a simple one-speed gearbox.",
                 shape: .cylinder(height: 0.5, radius: 0.02), material: .moving,
                 position: .zero, axis: [1, 0, 0], explodedPosition: .zero),
            Part(id: "rotor", name: "Rotor",
                 about: "The spinning part. Magnets (or induced currents) in it are pushed around by the stator's magnetic field.",
                 shape: .cylinder(height: 0.2, radius: 0.08), material: .moving,
                 position: .zero, axis: [1, 0, 0], explodedPosition: [0, 0.35, 0]),
            Part(id: "stator", name: "Stator",
                 about: "The fixed ring of copper coils. Switching current through them creates a rotating magnetic field that drags the rotor around.",
                 shape: .cylinder(height: 0.22, radius: 0.13), material: .electrical,
                 position: .zero, axis: [1, 0, 0], explodedPosition: [0, -0.35, 0]),
            Part(id: "housing", name: "Motor housing",
                 about: "The outer case. It protects the motor and carries away heat, often with liquid cooling.",
                 shape: .cylinder(height: 0.26, radius: 0.16), material: .block,
                 position: .zero, axis: [1, 0, 0], explodedPosition: [0, 0, -0.45]),
            Part(id: "inverter", name: "Inverter",
                 about: "Converts the battery's DC power into the rapidly switching AC that drives the stator. It controls the car's speed and power.",
                 shape: .box([0.2, 0.08, 0.16]), material: .cover,
                 position: [0, 0.22, 0], axis: [0, 1, 0], explodedPosition: [0, 0.65, 0]),
            Part(id: "end-cap", name: "End cap and bearing",
                 about: "Holds the spinning shaft precisely centred so the rotor never touches the stator.",
                 shape: .cylinder(height: 0.03, radius: 0.16), material: .cover,
                 position: [0.15, 0, 0], axis: [1, 0, 0], explodedPosition: [0.5, 0, 0]),
        ]
    }
}
