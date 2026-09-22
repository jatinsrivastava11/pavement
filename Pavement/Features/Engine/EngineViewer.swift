import RealityKit
import SwiftUI

/// Interactive 3D engine: drag to rotate, pinch to zoom, explode it apart, tap a part to learn about it.
struct EngineViewer: View {
    let engine: EngineType
    private let blueprint: EngineBlueprint

    @State private var exploded = false
    @State private var selected: EngineBlueprint.Part?
    @State private var yaw: Float = -0.6
    @State private var pitch: Float = 0.35
    @State private var dragStart: (Float, Float)?
    @State private var zoom: Float = 1
    @State private var zoomStart: Float?
    @State private var root = Entity()

    init(engine: EngineType) {
        self.engine = engine
        blueprint = EngineBlueprint(engine: engine)
        #if DEBUG
        _exploded = State(initialValue: UserDefaults.standard.bool(forKey: "previewExploded"))
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            RealityView { content in
                content.camera = .virtual
                build(into: root)
                content.add(root)
                let camera = PerspectiveCamera()
                camera.look(at: .zero, from: [0, 0.25, 1.3], relativeTo: nil)
                content.add(camera)
                let light = DirectionalLight()
                light.light.intensity = 3_000
                light.look(at: .zero, from: [0.6, 1, 0.8], relativeTo: nil)
                content.add(light)
            } update: { _ in
                root.orientation = simd_quatf(angle: pitch, axis: [1, 0, 0]) * simd_quatf(angle: yaw, axis: [0, 1, 0])
                // Zoom out when exploded so the flying parts stay on screen.
                root.scale = .init(repeating: zoom * (exploded ? 0.55 : 1))
                for part in blueprint.parts {
                    guard let entity = root.findEntity(named: part.id) as? ModelEntity else { continue }
                    var t = entity.transform
                    t.translation = exploded ? part.explodedPosition : part.position
                    entity.move(to: t, relativeTo: root, duration: 0.6, timingFunction: .easeInOut)
                    entity.model?.materials = [material(part.material, highlighted: part.id == selected?.id)]
                }
            }
            .gesture(SpatialTapGesture().targetedToAnyEntity().onEnded { value in
                selected = blueprint.parts.first { $0.id == value.entity.name }
            })
            .simultaneousGesture(DragGesture(minimumDistance: 4)
                .onChanged { g in
                    if dragStart == nil { dragStart = (yaw, pitch) }
                    yaw = dragStart!.0 + Float(g.translation.width) / 150
                    pitch = min(max(dragStart!.1 + Float(g.translation.height) / 150, -1.2), 1.2)
                }
                .onEnded { _ in dragStart = nil })
            .simultaneousGesture(MagnifyGesture()
                .onChanged { g in
                    if zoomStart == nil { zoomStart = zoom }
                    zoom = min(max(zoomStart! * Float(g.magnification), 0.5), 2.5)
                }
                .onEnded { _ in zoomStart = nil })
            .background(Theme.background)
            .accessibilityLabel("3D \(engine.displayName) engine. Drag to rotate, pinch to zoom.")

            infoPanel
        }
        .background(Theme.background)
    }

    private var infoPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(engine.displayName).font(.title2.weight(.heavy)).foregroundStyle(Theme.textPrimary)
                Spacer()
                Button(exploded ? "Put back together" : "Explode") {
                    exploded.toggle()
                }
                .font(.headline)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .foregroundStyle(Theme.onAccent)
                .background(Theme.accent, in: Capsule())
            }
            if let selected {
                Text(selected.name).font(.headline).foregroundStyle(Theme.accent)
                Text(selected.about).font(.subheadline).foregroundStyle(Theme.textPrimary)
            } else {
                Text(blueprint.summary).font(.subheadline).foregroundStyle(Theme.textSecondary)
                Text("Tap any part to learn what it does.").font(.caption).foregroundStyle(Theme.textSecondary)
            }
            // Parts list: tap-friendly and accessible alternative to tapping in 3D.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(uniquePartKinds, id: \.id) { part in
                        Button(part.name.replacingOccurrences(of: #" \d+$"#, with: "", options: .regularExpression)) {
                            selected = part
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .foregroundStyle(selected?.id == part.id ? .black : Theme.textPrimary)
                        .background(selected?.id == part.id ? Theme.accent : Theme.surfaceRaised, in: Capsule())
                    }
                }
            }
        }
        .padding(Theme.spacing)
        .background(Theme.surface)
    }

    /// One chip per kind of part (one "Piston" instead of eight).
    private var uniquePartKinds: [EngineBlueprint.Part] {
        var seen = Set<String>()
        return blueprint.parts.filter { part in
            let kind = part.name.replacingOccurrences(of: #" \d+$| \(bank \d+\)$"#, with: "", options: .regularExpression)
            return seen.insert(kind).inserted
        }
    }

    private func build(into root: Entity) {
        for part in blueprint.parts {
            let mesh: MeshResource = switch part.shape {
            case .box(let size): .generateBox(size: size, cornerRadius: 0.006)
            case .cylinder(let height, let radius): .generateCylinder(height: height, radius: radius)
            }
            let entity = ModelEntity(mesh: mesh, materials: [material(part.material, highlighted: false)])
            entity.name = part.id
            entity.position = part.position
            // Meshes are built along +y; turn them to face the part's axis.
            entity.orientation = simd_quatf(from: [0, 1, 0], to: simd_normalize(part.axis))
            entity.generateCollisionShapes(recursive: false)
            entity.components.set(InputTargetComponent())
            root.addChild(entity)
        }
    }

    private func material(_ kind: EngineBlueprint.Material, highlighted: Bool) -> SimpleMaterial {
        if highlighted { return SimpleMaterial(color: UIColor(Theme.accent), roughness: 0.3, isMetallic: true) }
        let (color, metal): (UIColor, Bool) = switch kind {
        case .block: (UIColor(white: 0.42, alpha: 1), true)
        case .head: (UIColor(red: 0.55, green: 0.1, blue: 0.1, alpha: 1), false)
        case .moving: (UIColor(white: 0.82, alpha: 1), true)
        case .manifold: (UIColor(white: 0.2, alpha: 1), false)
        case .exhaust: (UIColor(red: 0.62, green: 0.4, blue: 0.25, alpha: 1), true)
        case .electrical: (UIColor(red: 0.8, green: 0.45, blue: 0.2, alpha: 1), true)
        case .cover: (UIColor(white: 0.12, alpha: 1), false)
        }
        return SimpleMaterial(color: color, roughness: 0.45, isMetallic: metal)
    }
}

#Preview { EngineViewer(engine: .v8) }
