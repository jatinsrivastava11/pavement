import RealityKit
import SwiftUI

/// Interactive 3D engine: drag to rotate, pinch to zoom, explode it apart, tap a part to learn about it.
/// Each part category (block, painted head, polished moving parts, rubber hoses…) gets its own
/// physically based material, lit by a small procedural studio environment so metal actually shines.
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
                let lightSource = StudioLighting.addEnvironment(to: content, dark: Theme.colorScheme == .dark)
                build(into: root, lightSource: lightSource)
                content.add(root)
                let camera = PerspectiveCamera()
                camera.look(at: .zero, from: [0, 0.25, 1.3], relativeTo: nil)
                content.add(camera)
                let light = DirectionalLight()
                light.light.intensity = 1_800
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

    private func build(into root: Entity, lightSource: Entity?) {
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
            if let lightSource {
                entity.components.set(ImageBasedLightReceiverComponent(imageBasedLight: lightSource))
            }
            root.addChild(entity)
        }
    }

    private func material(_ kind: EngineBlueprint.Material, highlighted: Bool) -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        if highlighted {
            m.baseColor = .init(tint: UIColor(Theme.accent), texture: nil)
            m.metallic = 0.8
            m.roughness = 0.2
            return m
        }
        switch kind {
        case .block:
            // Cast aluminum: a dull, slightly rough metal, not a mirror.
            m.baseColor = .init(tint: UIColor(white: 0.45, alpha: 1), texture: nil)
            m.metallic = 0.85
            m.roughness = 0.55
        case .head:
            // A painted valve cover: colored base coat under a glossy clear coat, like car paint.
            m.baseColor = .init(tint: UIColor(red: 0.62, green: 0.08, blue: 0.09, alpha: 1), texture: nil)
            m.metallic = 0.3
            m.roughness = 0.3
            m.clearcoat = 0.9
            m.clearcoatRoughness = 0.08
        case .moving:
            // Polished steel: pistons, crankshaft, flywheel.
            m.baseColor = .init(tint: UIColor(white: 0.85, alpha: 1), texture: nil)
            m.metallic = 1.0
            m.roughness = 0.16
        case .manifold:
            m.baseColor = .init(tint: UIColor(white: 0.15, alpha: 1), texture: nil)
            m.metallic = 0.1
            m.roughness = 0.7
        case .exhaust:
            // Warm, slightly heat-discolored steel.
            m.baseColor = .init(tint: UIColor(red: 0.58, green: 0.38, blue: 0.26, alpha: 1), texture: nil)
            m.metallic = 0.9
            m.roughness = 0.35
        case .electrical:
            m.baseColor = .init(tint: UIColor(red: 0.75, green: 0.42, blue: 0.16, alpha: 1), texture: nil)
            m.metallic = 0.7
            m.roughness = 0.4
        case .cover:
            // Rubber and dark plastic: no shine at all.
            m.baseColor = .init(tint: UIColor(white: 0.08, alpha: 1), texture: nil)
            m.metallic = 0.0
            m.roughness = 0.9
        }
        return m
    }
}

#Preview { EngineViewer(engine: .v8) }
