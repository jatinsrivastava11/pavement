import UIKit

/// Saves spot photos (the cropped car) on the phone only. They're never uploaded.
struct SpotPhotoStore: Sendable {
    let directory: URL

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pavement", isDirectory: true)
        self.directory = base.appendingPathComponent("Photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    /// Saves the image as JPEG and returns its file name.
    func save(_ image: UIImage) throws -> String {
        let name = UUID().uuidString + ".jpg"
        guard let data = image.jpegData(compressionQuality: 0.85) else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: directory.appendingPathComponent(name), options: .atomic)
        return name
    }

    /// Deletes every saved spot photo.
    func removeAll() throws {
        for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            try FileManager.default.removeItem(at: file)
        }
    }

    func image(named name: String) -> UIImage? {
        UIImage(contentsOfFile: directory.appendingPathComponent(name).path)
    }
}
