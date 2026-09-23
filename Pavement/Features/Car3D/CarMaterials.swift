import CoreGraphics
import RealityKit
import UIKit
import simd

/// What kind of surface a palette swatch represents, so each gets its own physically based look
/// instead of the whole car sharing one flat material.
///
/// Kenney's kit reuses one shared palette across every vehicle. These thresholds were read
/// directly off that palette (Pavement/Resources/Cars3D/kenney-colormap.png): black is tires,
/// pale blue/lavender near white is glass, mid grey-blue is chrome trim, and anything strongly
/// colored is paint.
enum SwatchMaterial: String, CaseIterable, Sendable {
    case paint, glass, chrome, tire, highlight, plastic

    static func classify(_ rgb: BodyPaint.RGB) -> SwatchMaterial {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        UIColor(red: CGFloat(rgb.r) / 255, green: CGFloat(rgb.g) / 255, blue: CGFloat(rgb.b) / 255, alpha: 1)
            .getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        let hue = Double(h) * 360, sat = Double(s), bri = Double(b)
        let isBlueGrey = hue > 180 && hue < 270

        if sat < 0.08, bri < 0.12 { return .tire }
        if sat < 0.08, bri > 0.92 { return .highlight }
        if sat >= 0.08, sat < 0.35, bri > 0.94, isBlueGrey { return .glass }
        // Matches BodyPaint's own "is this a paint color" rule, so the two agree.
        if sat >= 0.35, bri > 0.35 { return .paint }
        if sat < 0.25, bri >= 0.50, bri < 0.94, isBlueGrey { return .chrome }
        return .plastic
    }

    /// A physically based material for this surface. `texture` still supplies the actual color
    /// (paint jobs vary within the category); only the surface *behavior* — how metallic, how
    /// rough, clear coat, transparency — differs by category.
    func material(texture: TextureResource?) -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: .white, texture: texture.map { .init($0) })
        switch self {
        case .paint:
            // Real car paint: a colored base coat under a glossy, near-mirror clear coat.
            m.metallic = 0.6
            m.roughness = 0.28
            m.clearcoat = 1.0
            m.clearcoatRoughness = 0.06
        case .glass:
            m.metallic = 0.0
            m.roughness = 0.05
            m.blending = .transparent(opacity: .init(floatLiteral: 0.55))
            m.clearcoat = 0.5
            m.clearcoatRoughness = 0.05
        case .chrome:
            m.metallic = 1.0
            m.roughness = 0.14
        case .tire:
            m.metallic = 0.0
            m.roughness = 0.95
        case .highlight:
            // Headlights and other bright trim: bright but not mirror-like.
            m.metallic = 0.05
            m.roughness = 0.2
        case .plastic:
            m.metallic = 0.05
            m.roughness = 0.6
        }
        return m
    }
}

/// Splits an OBJ mesh into one sub-mesh per material category, by sampling the palette color each
/// triangle uses. `OBJMesh` already gives every triangle corner its own vertex (no sharing), so
/// triangles simply sort into buckets; nothing needs re-indexing beyond that.
enum MeshSplitter {
    struct Group {
        let category: SwatchMaterial
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
    }

    static func split(_ mesh: OBJMesh, texture: CGImage) -> [Group] {
        let px = BodyPaint.pixels(of: texture)
        var buckets: [SwatchMaterial: Group] = [:]

        for t in stride(from: 0, to: mesh.indices.count, by: 3) {
            let corners = (0..<3).map { Int(mesh.indices[t + $0]) }
            let uv = corners.reduce(SIMD2<Float>.zero) { $0 + mesh.uvs[$1] } / 3
            // OBJ texture coordinates start at the bottom of the image.
            let x = min(texture.width - 1, max(0, Int(uv.x * Float(texture.width))))
            let y = min(texture.height - 1, max(0, Int((1 - uv.y) * Float(texture.height))))
            let i = (y * texture.width + x) * 4
            let category = SwatchMaterial.classify(.init(r: px[i], g: px[i + 1], b: px[i + 2]))
            var group = buckets[category] ?? Group(category: category)
            for corner in corners {
                group.positions.append(mesh.positions[corner])
                group.normals.append(mesh.normals[corner])
                group.uvs.append(mesh.uvs[corner])
            }
            buckets[category] = group
        }
        // A stable order, so material arrays line up the same way every time.
        return SwatchMaterial.allCases.compactMap { buckets[$0] }
    }
}
