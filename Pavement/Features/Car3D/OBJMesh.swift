import Foundation
import simd

/// A triangle mesh read from Wavefront OBJ text (positions, normals, texture coordinates).
///
/// Only what Pavement's car models use: `v`, `vn`, `vt` and `f` lines, with polygons split into
/// triangles. Every triangle corner becomes its own vertex, which keeps flat-shaded normals sharp.
struct OBJMesh: Sendable {
    var positions: [SIMD3<Float>] = []
    var normals: [SIMD3<Float>] = []
    var uvs: [SIMD2<Float>] = []
    var indices: [UInt32] = []

    var boundsMin: SIMD3<Float> { positions.reduce(SIMD3(repeating: .infinity)) { simd_min($0, $1) } }
    var boundsMax: SIMD3<Float> { positions.reduce(SIMD3(repeating: -.infinity)) { simd_max($0, $1) } }

    enum ParseError: Error { case badFace(line: Int), empty }

    init(text: String) throws {
        var v: [SIMD3<Float>] = [], vn: [SIMD3<Float>] = [], vt: [SIMD2<Float>] = []
        for (n, raw) in text.split(whereSeparator: \.isNewline).enumerated() {
            let parts = raw.split(separator: " ", omittingEmptySubsequences: true)
            guard let tag = parts.first else { continue }
            let nums = { parts.dropFirst().compactMap { Float($0) } }
            switch tag {
            case "v": let f = nums(); if f.count >= 3 { v.append([f[0], f[1], f[2]]) }
            case "vn": let f = nums(); if f.count >= 3 { vn.append([f[0], f[1], f[2]]) }
            case "vt": let f = nums(); if f.count >= 2 { vt.append([f[0], f[1]]) }
            case "f":
                // Each corner is v, v/vt, v//vn or v/vt/vn (1-based; negative = from the end).
                let corners: [(Int, Int?, Int?)] = try parts.dropFirst().map { corner in
                    let idx = corner.split(separator: "/", omittingEmptySubsequences: false).map { Int($0) }
                    func resolve(_ i: Int?, _ count: Int) -> Int? { i.map { $0 < 0 ? count + $0 : $0 - 1 } }
                    guard let p = resolve(idx.first ?? nil, v.count), v.indices.contains(p) else { throw ParseError.badFace(line: n + 1) }
                    return (p, idx.count > 1 ? resolve(idx[1], vt.count) : nil, idx.count > 2 ? resolve(idx[2], vn.count) : nil)
                }
                guard corners.count >= 3 else { throw ParseError.badFace(line: n + 1) }
                for i in 1..<(corners.count - 1) {           // fan triangulation
                    let tri = [corners[0], corners[i], corners[i + 1]]
                    let a = v[tri[0].0], b = v[tri[1].0], c = v[tri[2].0]
                    let faceNormal = simd_normalize(simd_cross(b - a, c - a))
                    for (p, t, nIdx) in tri {
                        indices.append(UInt32(positions.count))
                        positions.append(v[p])
                        normals.append(nIdx.flatMap { vn.indices.contains($0) ? vn[$0] : nil } ?? faceNormal)
                        uvs.append(t.flatMap { vt.indices.contains($0) ? vt[$0] : nil } ?? .zero)
                    }
                }
            default: continue
            }
        }
        guard !indices.isEmpty else { throw ParseError.empty }
    }
}
