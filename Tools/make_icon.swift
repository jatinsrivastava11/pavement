// Draws Pavement's app icon (1024×1024): asphalt, a yellow road line into the distance, a car.
//   swift Tools/make_icon.swift Pavement/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import AppKit
import SwiftUI

struct Icon: View {
    let asphalt = Color(red: 0.07, green: 0.07, blue: 0.08)
    let yellow = Color(red: 1.0, green: 0.80, blue: 0.16)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.16, green: 0.16, blue: 0.19), asphalt], startPoint: .top, endPoint: .bottom)
            // Road edges converging to the horizon.
            Path { p in
                p.move(to: CGPoint(x: 120, y: 1024)); p.addLine(to: CGPoint(x: 470, y: 430))
                p.addLine(to: CGPoint(x: 554, y: 430)); p.addLine(to: CGPoint(x: 904, y: 1024)); p.closeSubpath()
            }
            .fill(LinearGradient(colors: [Color(white: 0.2), Color(white: 0.11)], startPoint: .top, endPoint: .bottom))
            // Dashed centre line, getting smaller toward the horizon.
            ForEach(0..<4) { i in
                let t = Double(i) / 4
                let y = 1024 - pow(t, 0.7) * 590
                let h = 130 * (1 - t * 0.8)
                let w = 34 * (1 - t * 0.8)
                RoundedRectangle(cornerRadius: w / 3).fill(yellow)
                    .frame(width: w, height: h).position(x: 512, y: y - h / 2)
            }
            // Car silhouette on the horizon: our own drawing (SF Symbols aren't allowed in app icons).
            CarShape().fill(yellow)
                .frame(width: 340, height: 130)
                .shadow(color: yellow.opacity(0.35), radius: 30)
                .position(x: 512, y: 340)
        }
        .frame(width: 1024, height: 1024)
    }
}

/// A low sports-coupe side profile with two wheel cut-outs.
struct CarShape: Shape {
    func path(in r: CGRect) -> Path {
        func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height) }
        var body = Path()
        body.move(to: pt(0.02, 0.78))
        body.addLine(to: pt(0.02, 0.58))
        body.addQuadCurve(to: pt(0.2, 0.42), control: pt(0.04, 0.44))
        body.addLine(to: pt(0.33, 0.38))
        body.addQuadCurve(to: pt(0.62, 0.06), control: pt(0.42, 0.06))
        body.addQuadCurve(to: pt(0.86, 0.38), control: pt(0.78, 0.08))
        body.addQuadCurve(to: pt(0.99, 0.55), control: pt(0.98, 0.4))
        body.addLine(to: pt(0.99, 0.78))
        body.closeSubpath()
        var wheels = Path()
        for cx in [0.24, 0.78] {
            wheels.addEllipse(in: CGRect(x: r.minX + (cx - 0.1) * r.width, y: r.minY + 0.56 * r.height,
                                         width: 0.2 * r.width, height: 0.2 * r.width))
        }
        var windows = Path()
        windows.move(to: pt(0.4, 0.37)); windows.addQuadCurve(to: pt(0.6, 0.14), control: pt(0.46, 0.15))
        windows.addLine(to: pt(0.6, 0.37)); windows.closeSubpath()
        windows.move(to: pt(0.64, 0.14)); windows.addQuadCurve(to: pt(0.8, 0.37), control: pt(0.76, 0.16))
        windows.addLine(to: pt(0.64, 0.37)); windows.closeSubpath()
        return body.subtracting(wheels.union(windows)).union(
            Path { p in for cx in [0.24, 0.78] {
                p.addEllipse(in: CGRect(x: r.minX + (cx - 0.075) * r.width, y: r.minY + 0.585 * r.height,
                                        width: 0.15 * r.width, height: 0.15 * r.width))
            } })
    }
}

MainActor.assumeIsolated {
    let renderer = ImageRenderer(content: Icon())
    renderer.scale = 1
    guard let cg = renderer.cgImage else { fatalError("render failed") }
    let rep = NSBitmapImageRep(cgImage: cg)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
    print("wrote \(CommandLine.arguments[1]) \(cg.width)x\(cg.height)")
}
