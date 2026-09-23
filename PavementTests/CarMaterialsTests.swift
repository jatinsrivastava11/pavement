import Testing
import RealityKit
import UIKit
@testable import Pavement

struct SwatchMaterialTests {
    private func rgb(_ r: Int, _ g: Int, _ b: Int) -> BodyPaint.RGB { .init(r: UInt8(r), g: UInt8(g), b: UInt8(b)) }

    @Test("Real palette swatches classify correctly", arguments: [
        // Exact colors measured from Pavement/Resources/Cars3D/kenney-colormap.png.
        (0, 0, 0, SwatchMaterial.tire),
        (255, 255, 255, .highlight),
        (208, 232, 255, .glass),          // pale windshield blue
        (199, 182, 255, .glass),          // pale windshield lavender
        (134, 139, 161, .chrome),         // grille / trim
        (160, 168, 201, .chrome),
        (56, 56, 61, .plastic),           // dark chassis
        (79, 82, 96, .plastic),
        (222, 67, 62, .paint),            // red
        (103, 148, 217, .paint),          // blue
        (97, 203, 139, .paint),           // green
        (255, 194, 20, .paint),           // gold
        (243, 120, 240, .paint),          // magenta
    ])
    func classifiesRealSwatches(r: Int, g: Int, b: Int, expected: SwatchMaterial) {
        #expect(SwatchMaterial.classify(rgb(r, g, b)) == expected, "(\(r),\(g),\(b))")
    }

    // Constructing a PhysicallyBasedMaterial and reading back .metallic/.roughness/.blending needs
    // a live RealityKit render context (it crashes in a plain unit test process), so those
    // properties are checked visually instead — see Tools/screenshot notes in CarViewer/EngineViewer.
    // classify() itself, which is what actually decides which look each part gets, IS fully
    // unit-tested above against real palette colors.
}

struct MeshSplitterTests {
    private func checkerTexture(size: Int = 64) -> CGImage {
        let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        // Left half: pure black (tire). Right half: saturated red (paint).
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: size / 2, height: size))
        ctx.setFillColor(CGColor(red: 0.87, green: 0.26, blue: 0.24, alpha: 1))
        ctx.fill(CGRect(x: size / 2, y: 0, width: size / 2, height: size))
        return ctx.makeImage()!
    }

    /// Two triangles: one entirely in the black half, one entirely in the red half.
    private func twoTriangleMesh() throws -> OBJMesh {
        try OBJMesh(text: """
        v 0 0 0
        v 1 0 0
        v 0 1 0
        v 2 0 0
        v 3 0 0
        v 2 1 0
        vt 0.1 0.5
        vt 0.1 0.5
        vt 0.1 0.5
        vt 0.9 0.5
        vt 0.9 0.5
        vt 0.9 0.5
        f 1/1 2/2 3/3
        f 4/4 5/5 6/6
        """)
    }

    @Test("Splits into exactly the categories present, with no triangle lost or duplicated")
    func splitsCorrectly() throws {
        let mesh = try twoTriangleMesh()
        let groups = MeshSplitter.split(mesh, texture: checkerTexture())
        #expect(Set(groups.map(\.category)) == [.tire, .paint])
        let totalVertices = groups.reduce(0) { $0 + $1.positions.count }
        #expect(totalVertices == mesh.positions.count)   // 6 corners in, 6 corners out
        for group in groups {
            #expect(group.positions.count == 3, "\(group.category) should be exactly one triangle")
            #expect(group.normals.count == group.positions.count)
            #expect(group.uvs.count == group.positions.count)
        }
    }

    @Test("Every bundled car body splits into at least a paint group, and covers every triangle",
          arguments: [BodyStyle.sedan, .suv, .pickup, .van, .coupe])
    func realCarsSplit(body: BodyStyle) throws {
        let mesh = try CarBody.mesh(named: CarBody.modelName(for: body, tier: .common))
        guard let url = Bundle.main.url(forResource: "kenney-colormap", withExtension: "png"),
              let texture = UIImage(contentsOfFile: url.path)?.cgImage else {
            Issue.record("palette texture missing"); return
        }
        let groups = MeshSplitter.split(mesh, texture: texture)
        #expect(groups.contains { $0.category == .paint })
        let totalTriangles = groups.reduce(0) { $0 + $1.positions.count / 3 }
        #expect(totalTriangles == mesh.indices.count / 3, "\(body): no triangle should be lost or duplicated")
    }
}
