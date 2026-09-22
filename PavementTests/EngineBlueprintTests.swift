import Testing
import simd
@testable import Pavement

struct EngineBlueprintTests {
    private func pistons(_ e: EngineType) -> [EngineBlueprint.Part] {
        EngineBlueprint(engine: e).parts.filter { $0.id.hasPrefix("piston-") }
    }

    @Test("Right number of pistons for every piston engine", arguments: [
        (EngineType.i3, 3), (.i4, 4), (.i5, 5), (.i6, 6), (.v6, 6), (.v8, 8), (.v10, 10),
        (.v12, 12), (.v16, 16), (.flat4, 4), (.flat6, 6), (.w12, 12), (.w16, 16),
    ])
    func pistonCount(engine: EngineType, count: Int) {
        #expect(pistons(engine).count == count)
    }

    @Test("Electric motors and rotaries have no pistons")
    func noPistons() {
        #expect(pistons(.electric).isEmpty)
        #expect(pistons(.rotary).isEmpty)
        #expect(EngineBlueprint(engine: .rotary).parts.filter { $0.id.hasPrefix("rotor-") }.count == 2)
    }

    @Test("Inline pistons stand straight up; V8 banks lean 45° each way; boxer pistons lie flat")
    func bankGeometry() {
        #expect(pistons(.i4).allSatisfy { abs($0.axis.y - 1) < 0.001 })
        let v8 = pistons(.v8).map(\.axis)
        #expect(v8.contains { abs($0.z - sin(.pi / 4)) < 0.001 } && v8.contains { abs($0.z + sin(.pi / 4)) < 0.001 })
        #expect(pistons(.flat6).allSatisfy { abs($0.axis.y) < 0.001 && abs(abs($0.axis.z) - 1) < 0.001 })
    }

    @Test("Every engine type has unique part IDs and a summary", arguments: EngineType.allCases)
    func uniqueParts(engine: EngineType) {
        let bp = EngineBlueprint(engine: engine)
        #expect(Set(bp.parts.map(\.id)).count == bp.parts.count)
        #expect(!bp.summary.isEmpty)
        #expect(bp.parts.allSatisfy { !$0.about.isEmpty })
    }

    @Test("Exploding moves every part outward (or leaves the core in place)", arguments: EngineType.allCases)
    func explodesOutward(engine: EngineType) {
        for part in EngineBlueprint(engine: engine).parts {
            #expect(length(part.explodedPosition) >= length(part.position) - 0.001, "\(engine) \(part.name)")
        }
        // And something actually moves.
        #expect(EngineBlueprint(engine: engine).parts.contains { length($0.explodedPosition - $0.position) > 0.2 })
    }

    @Test("Pistons in a bank are evenly spaced along the crankshaft")
    func spacing() {
        let xs = pistons(.i6).map(\.position.x).sorted()
        let gaps = zip(xs, xs.dropFirst()).map { $1 - $0 }
        #expect(gaps.allSatisfy { abs($0 - gaps[0]) < 0.0001 })
    }
}
