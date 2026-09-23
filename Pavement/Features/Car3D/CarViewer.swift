import RealityKit
import SwiftUI

/// Interactive 3D car in the car's body style: drag to rotate, pinch to zoom, and optionally
/// painted in the color of the car in your photo. The body, glass, chrome and tires are separate
/// child entities so each can get its own physically based material, lit by a small procedural
/// studio environment, so metal and glass actually reflect something instead of looking flat.
struct CarViewer: View {
    let car: CarModel
    /// Paint color taken from the user's photo, if there is one.
    let photoColor: UIColor?

    @State private var matchColor = true
    @State private var yaw: Float = -0.7
    @State private var pitch: Float = 0.3
    @State private var dragStart: (Float, Float)?
    @State private var zoom: Float = 1
    @State private var zoomStart: Float?
    @State private var root = Entity()
    @State private var loadError: String?
    /// Textures live in a plain object: they're created inside RealityView's setup, where changing
    /// view state doesn't take effect in time for the first frame.
    final class Textures { var original: TextureResource?; var painted: TextureResource? }
    @State private var textures = Textures()

    var body: some View {
        VStack(spacing: 0) {
            RealityView { content in
                content.camera = .virtual
                let lightSource = StudioLighting.addEnvironment(to: content, dark: Theme.colorScheme == .dark)
                if let model = makeModel(lightSource: lightSource) { root.addChild(model) }
                content.add(root)
                let camera = PerspectiveCamera()
                camera.look(at: .zero, from: [0, 0.5, 3.6], relativeTo: nil)
                content.add(camera)
                let light = DirectionalLight()
                light.light.intensity = 1_600
                light.look(at: .zero, from: [0.8, 1.2, 1], relativeTo: nil)
                content.add(light)
            } update: { _ in
                root.orientation = simd_quatf(angle: pitch, axis: [1, 0, 0]) * simd_quatf(angle: yaw, axis: [0, 1, 0])
                root.scale = .init(repeating: zoom)
                let texture = (matchColor ? textures.painted : nil) ?? textures.original
                guard let carEntity = root.children.first else { return }
                for child in carEntity.children {
                    guard let model = child as? ModelEntity, let category = SwatchMaterial(rawValue: child.name) else { continue }
                    model.model?.materials = [category.material(texture: texture)]
                }
            }
            .simultaneousGesture(DragGesture(minimumDistance: 4)
                .onChanged { g in
                    if dragStart == nil { dragStart = (yaw, pitch) }
                    yaw = dragStart!.0 + Float(g.translation.width) / 150
                    pitch = min(max(dragStart!.1 + Float(g.translation.height) / 150, -0.2), 1.2)
                }
                .onEnded { _ in dragStart = nil })
            .simultaneousGesture(MagnifyGesture()
                .onChanged { g in
                    if zoomStart == nil { zoomStart = zoom }
                    zoom = min(max(zoomStart! * Float(g.magnification), 0.5), 2.5)
                }
                .onEnded { _ in zoomStart = nil })
            .background(Theme.background)
            .accessibilityLabel("3D \(car.body.displayName) model. Drag to rotate, pinch to zoom.")

            VStack(alignment: .leading, spacing: 10) {
                Text(car.displayName).font(.title2.weight(.heavy)).foregroundStyle(Theme.textPrimary)
                Text("A \(car.body.displayName.lowercased()) model like this car's shape. Exact 3D models of each car come later.")
                    .font(.subheadline).foregroundStyle(Theme.textSecondary).fixedSize(horizontal: false, vertical: true)
                if photoColor != nil {
                    Toggle("Match the color in my photo", isOn: $matchColor).tint(Theme.accent)
                }
                if let loadError { Text(loadError).font(.footnote).foregroundStyle(Theme.danger) }
                Text("3D model: Car Kit by Kenney (CC0)").font(.caption2).foregroundStyle(Theme.textSecondary)
            }
            .padding(Theme.spacing)
            .background(Theme.surface)
        }
        .background(Theme.background)
    }

    /// One parent entity holding one child `ModelEntity` per material category (mirrors how
    /// EngineViewer builds its parts — proven to render correctly, unlike a single multi-part mesh).
    private func makeModel(lightSource: Entity?) -> Entity? {
        do {
            let obj = try CarBody.mesh(named: CarBody.modelName(for: car.body, tier: car.tier))
            guard let paletteImage = UIImage(named: "kenney-colormap")?.cgImage else { throw CocoaError(.fileReadUnknown) }
            prepareTextures(for: obj, paletteImage: paletteImage)

            let parent = Entity()
            for group in MeshSplitter.split(obj, texture: paletteImage) {
                var d = MeshDescriptor(name: "car-\(group.category)")
                d.positions = MeshBuffer(group.positions)
                d.normals = MeshBuffer(group.normals)
                d.textureCoordinates = MeshBuffer(group.uvs)
                d.primitives = .triangles(Array(0..<UInt32(group.positions.count)))
                let child = ModelEntity(mesh: try .generate(from: [d]), materials: [group.category.material(texture: textures.original)])
                child.name = group.category.rawValue
                if let lightSource {
                    child.components.set(ImageBasedLightReceiverComponent(imageBasedLight: lightSource))
                }
                parent.addChild(child)
            }
            // Centre and scale the whole car to about 1.6 m long so every body style fills the view
            // the same way; children keep the mesh's own local positions and inherit this transform.
            let size = obj.boundsMax - obj.boundsMin
            let scale = 1.6 / max(size.x, size.z)
            parent.scale = .init(repeating: scale)
            parent.position = -((obj.boundsMin + obj.boundsMax) / 2) * scale
            return parent
        } catch {
            loadError = "Couldn't load the 3D model."
            return nil
        }
    }

    /// Loads the palette, and a copy with the body repainted in the photo's color.
    private func prepareTextures(for obj: OBJMesh, paletteImage: CGImage) {
        textures.original = try? TextureResource(image: paletteImage, options: .init(semantic: .color))
        if let photoColor, let painted = BodyPaint.repaint(texture: paletteImage, body: BodyPaint.bodyColor(mesh: obj, texture: paletteImage), paint: photoColor) {
            textures.painted = try? TextureResource(image: painted, options: .init(semantic: .color))
        }
    }
}

#Preview {
    CarViewer(car: CarModel(id: "x", make: "Honda", model: "Civic", tier: .common, engine: .i4, body: .sedan, approxBuilt: nil),
              photoColor: .systemRed)
}
