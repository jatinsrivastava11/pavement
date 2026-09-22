import CoreGraphics
import Testing
import UIKit
import simd
@testable import Pavement

struct OBJMeshTests {
    @Test("A quad becomes two triangles with positions, normals and texture coordinates")
    func quad() throws {
        let obj = """
        v 0 0 0
        v 1 0 0
        v 1 1 0
        v 0 1 0
        vt 0 0
        vt 1 0
        vt 1 1
        vt 0 1
        vn 0 0 1
        f 1/1/1 2/2/1 3/3/1 4/4/1
        """
        let m = try OBJMesh(text: obj)
        #expect(m.indices.count == 6)
        #expect(m.positions.count == 6 && m.normals.count == 6 && m.uvs.count == 6)
        #expect(m.normals.allSatisfy { $0 == [0, 0, 1] })
        #expect(m.uvs[2] == [1, 1])
    }

    @Test("Missing normals are computed from the triangle")
    func computedNormals() throws {
        let m = try OBJMesh(text: "v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 3")
        #expect(simd_distance(m.normals[0], [0, 0, 1]) < 0.0001)
    }

    @Test("A face pointing at a missing vertex is an error, not a crash")
    func badFace() {
        #expect(throws: OBJMesh.ParseError.self) { try OBJMesh(text: "v 0 0 0\nf 1 2 9") }
    }

    @Test("Every body style has a bundled 3D model that loads", arguments: BodyStyle.allCases)
    func everyBodyStyleLoads(body: BodyStyle) throws {
        let mesh = try CarBody.mesh(named: CarBody.modelName(for: body, tier: .common))
        #expect(mesh.indices.count > 1_000)
        let size = mesh.boundsMax - mesh.boundsMin
        #expect(size.x > 0 && size.y > 0 && size.z > 0)
    }

    @Test("Luxury SUVs for rare tiers, regular SUVs otherwise")
    func suvs() {
        #expect(CarBody.modelName(for: .suv, tier: .exotic) == "kenney-suv-luxury")
        #expect(CarBody.modelName(for: .suv, tier: .common) == "kenney-suv")
    }
}

struct CarColorTests {
    private func image(_ fill: (Int, Int) -> (CGFloat, CGFloat, CGFloat)) -> CGImage {
        let ctx = CGContext(data: nil, width: 60, height: 40, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        for y in 0..<40 { for x in 0..<60 {
            let (r, g, b) = fill(x, y)
            ctx.setFillColor(CGColor(red: r, green: g, blue: b, alpha: 1)); ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
        } }
        return ctx.makeImage()!
    }

    private func hsb(_ c: UIColor) -> (CGFloat, CGFloat, CGFloat) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0; c.getHue(&h, saturation: &s, brightness: &b, alpha: nil); return (h, s, b)
    }

    @Test("A red car on a grey road comes out red")
    func redCar() {
        let img = image { x, y in (15..<45).contains(x) && (10..<30).contains(y) ? (0.8, 0.1, 0.1) : (0.4, 0.4, 0.4) }
        let (h, s, _) = hsb(CarColor.dominant(in: img))
        #expect(s > 0.5 && (h < 0.05 || h > 0.95))
    }

    @Test("A blue car comes out blue")
    func blueCar() {
        let img = image { x, y in (10..<50).contains(x) && (8..<32).contains(y) ? (0.1, 0.25, 0.8) : (0.3, 0.3, 0.3) }
        let (h, s, _) = hsb(CarColor.dominant(in: img))
        #expect(s > 0.5 && h > 0.55 && h < 0.72)
    }

    @Test("A white car comes out light grey or white, not a color")
    func whiteCar() {
        let img = image { x, y in (10..<50).contains(x) && (8..<32).contains(y) ? (0.93, 0.93, 0.95) : (0.35, 0.35, 0.35) }
        let (_, s, b) = hsb(CarColor.dominant(in: img))
        #expect(s < 0.2 && b > 0.8)
    }
}

struct BodyPaintTests {
    private func colormap() throws -> CGImage {
        let url = try #require(Bundle.main.url(forResource: "kenney-colormap", withExtension: "png"))
        return try #require(UIImage(contentsOfFile: url.path)?.cgImage)
    }

    @Test("The sedan's body color is a strong, saturated paint color (not tyres or glass)")
    func sedanBody() throws {
        let body = BodyPaint.bodyColor(mesh: try CarBody.mesh(named: "kenney-sedan"), texture: try colormap())
        let c = UIColor(red: CGFloat(body.r) / 255, green: CGFloat(body.g) / 255, blue: CGFloat(body.b) / 255, alpha: 1)
        var s: CGFloat = 0, b: CGFloat = 0
        c.getHue(nil, saturation: &s, brightness: &b, alpha: nil)
        #expect(s > 0.4 && b > 0.4, "\(body)")
    }

    @Test("Repainting changes only colors close to the body paint")
    func repaintOnlyBody() throws {
        let tex = try colormap()
        let body = BodyPaint.bodyColor(mesh: try CarBody.mesh(named: "kenney-sedan"), texture: tex)
        let painted = try #require(BodyPaint.repaint(texture: tex, body: body, paint: UIColor(red: 0, green: 0, blue: 1, alpha: 1)))
        let before = BodyPaint.pixels(of: tex), after = BodyPaint.pixels(of: painted)
        var changed = 0, wrong = 0
        for i in stride(from: 0, to: before.count, by: 4) where before[i..<i + 3] != after[i..<i + 3] {
            changed += 1
            let c = BodyPaint.RGB(r: before[i], g: before[i + 1], b: before[i + 2])
            if BodyPaint.distance(c, body) >= BodyPaint.sameColorDistance { wrong += 1 }
        }
        #expect(changed > 0)
        #expect(wrong == 0)
    }
}

extension BodyPaintTests {
    @Test("The SUV's body is its green paint, not the hood or trim", arguments: ["kenney-suv"])
    func suvBodyIsMostCommonPaint(name: String) throws {
        let tex = try colormap()
        let mesh = try CarBody.mesh(named: name)
        let body = BodyPaint.bodyColor(mesh: mesh, texture: tex)
        let c = UIColor(red: CGFloat(body.r) / 255, green: CGFloat(body.g) / 255, blue: CGFloat(body.b) / 255, alpha: 1)
        var h: CGFloat = 0; c.getHue(&h, saturation: nil, brightness: nil, alpha: nil)
        #expect(h > 0.25 && h < 0.5, "hue \(h), \(body)")   // green
    }
}
