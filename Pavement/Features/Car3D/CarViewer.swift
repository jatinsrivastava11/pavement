import RealityKit
import SwiftUI

/// Interactive 3D car in the car's body style: drag to rotate, pinch to zoom, and optionally
/// painted in the color of the car in your photo.
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
                if let model = makeModel() { root.addChild(model) }
                content.add(root)
                let camera = PerspectiveCamera()
                camera.look(at: .zero, from: [0, 0.5, 3.6], relativeTo: nil)
                content.add(camera)
                let light = DirectionalLight()
                light.light.intensity = 2_500
                light.look(at: .zero, from: [0.8, 1.2, 1], relativeTo: nil)
                content.add(light)
            } update: { _ in
                root.orientation = simd_quatf(angle: pitch, axis: [1, 0, 0]) * simd_quatf(angle: yaw, axis: [0, 1, 0])
                root.scale = .init(repeating: zoom)
                if let model = root.children.first as? ModelEntity {
                    model.model?.materials = [material()]
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

    private func makeModel() -> ModelEntity? {
        do {
            let obj = try CarBody.mesh(named: CarBody.modelName(for: car.body, tier: car.tier))
            var descriptor = MeshDescriptor(name: "car")
            descriptor.positions = MeshBuffer(obj.positions)
            descriptor.normals = MeshBuffer(obj.normals)
            descriptor.textureCoordinates = MeshBuffer(obj.uvs)
            descriptor.primitives = .triangles(obj.indices)
            prepareTextures(for: obj)
            let entity = ModelEntity(mesh: try .generate(from: [descriptor]), materials: [material()])
            // Centre it and scale to about 1.6 m long so every body style fills the view the same way.
            let size = obj.boundsMax - obj.boundsMin
            let scale = 1.6 / max(size.x, size.z)
            entity.scale = .init(repeating: scale)
            entity.position = -((obj.boundsMin + obj.boundsMax) / 2) * scale
            return entity
        } catch {
            loadError = "Couldn't load the 3D model."
            return nil
        }
    }

    /// Loads the palette, and a copy with the body repainted in the photo's color.
    private func prepareTextures(for obj: OBJMesh) {
        guard let image = UIImage(named: "kenney-colormap")?.cgImage else { return }
        textures.original = try? TextureResource(image: image, options: .init(semantic: .color))
        if let photoColor, let painted = BodyPaint.repaint(texture: image, body: BodyPaint.bodyColor(mesh: obj, texture: image), paint: photoColor) {
            textures.painted = try? TextureResource(image: painted, options: .init(semantic: .color))
        }
    }

    private func material() -> SimpleMaterial {
        var m = SimpleMaterial()
        if let texture = (matchColor ? textures.painted : nil) ?? textures.original {
            m.color = .init(tint: .white, texture: .init(texture))
        }
        m.roughness = 0.55
        m.metallic = 0.1
        return m
    }
}

#Preview {
    CarViewer(car: CarModel(id: "x", make: "Honda", model: "Civic", tier: .common, engine: .i4, body: .sedan, approxBuilt: nil),
              photoColor: .systemRed)
}
