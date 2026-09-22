// Checks the car identifier on real photos, on the Mac (the iOS simulator can't run it properly:
// it returns the same answer for every image).
//
//   swiftc -O Tools/check_identifier.swift -o /tmp/check_identifier && /tmp/check_identifier
//
// Exits with an error if a check fails.
import CoreGraphics
import CoreML
import Foundation
import ImageIO
import Vision

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let model = try VNCoreMLModel(for: MLModel(contentsOf: MLModel.compileModel(
    at: root.appendingPathComponent("Pavement/Resources/Models/CarIdentifierPilot.mlmodel"))))
let minConfidence: Float = 0.95   // keep in sync with CarIdentifier.minConfidence

func top(_ photo: String, _ box: CGRect) throws -> (String, Float) {
    let url = root.appendingPathComponent("PavementTests/Fixtures/Streets/\(photo).jpg")
    let img = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(url as CFURL, nil)!, 0, nil)!
    let rect = CGRect(x: box.minX * Double(img.width), y: box.minY * Double(img.height),
                      width: box.width * Double(img.width), height: box.height * Double(img.height)).integral
    let request = VNCoreMLRequest(model: model)
    request.imageCropAndScaleOption = .centerCrop
    try VNImageRequestHandler(cgImage: img.cropping(to: rect)!).perform([request])
    let best = (request.results as! [VNClassificationObservation])[0]
    return (best.identifier, best.confidence)
}

func named(_ r: (String, Float)) -> String? { r.0 != "other" && r.1 >= minConfidence ? r.0 : nil }

var failures = 0
func check(_ what: String, _ ok: Bool, _ detail: String) {
    print("\(ok ? "PASS" : "FAIL")  \(what)  (\(detail))")
    if !ok { failures += 1 }
}

// Different photos must not all get the same answer (catches a broken/degenerate model).
let answers = try [top("street01", CGRect(x: 0.44, y: 0.35, width: 0.15, height: 0.18)),   // Tahoe
                   top("street01", CGRect(x: 0.615, y: 0.38, width: 0.13, height: 0.235)), // Beetle
                   top("street15", CGRect(x: 0.2, y: 0.2, width: 0.5, height: 0.5))]        // sky
check("Different images give different answers", Set(answers.map(\.0)).count > 1, "\(answers.map(\.0))")

let tahoe = try top("street01", CGRect(x: 0.44, y: 0.35, width: 0.15, height: 0.18))
check("Unknown model (Chevy Tahoe) is not named", named(tahoe) == nil, "\(tahoe.0) \(tahoe.1)")

let sky = try top("street15", CGRect(x: 0.2, y: 0.2, width: 0.5, height: 0.5))
check("No car (Milky Way) is not named", named(sky) == nil, "\(sky.0) \(sky.1)")

// Known weakness, reported but not failing: the Beetle seen from behind.
let beetle = try top("street01", CGRect(x: 0.615, y: 0.38, width: 0.13, height: 0.235))
print("INFO  VW Beetle from behind → \(named(beetle) ?? "not named") (\(beetle.0) \(beetle.1))")

exit(failures == 0 ? 0 : 1)
