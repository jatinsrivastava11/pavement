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
// Keep in sync with CarIdentifier.minConfidence / agreementConfidence.
let minConfidence: Float = 0.95
let agreementConfidence: Float = 0.9

struct Result { let label: String; let confidence: Float; let agrees: Bool }

func classify(_ img: CGImage) throws -> (String, Float) {
    let request = VNCoreMLRequest(model: model)
    request.imageCropAndScaleOption = .centerCrop
    try VNImageRequestHandler(cgImage: img).perform([request])
    let best = (request.results as! [VNClassificationObservation])[0]
    return (best.identifier, best.confidence)
}

func mirrored(_ image: CGImage) -> CGImage {
    let ctx = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: CGFloat(image.width), y: 0); ctx.scaleBy(x: -1, y: 1)
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return ctx.makeImage()!
}

func zoomed(_ image: CGImage) -> CGImage {
    let w = Double(image.width), h = Double(image.height)
    return image.cropping(to: CGRect(x: w * 0.08, y: h * 0.08, width: w * 0.84, height: h * 0.84).integral)!
}

func top(_ photo: String, _ box: CGRect) throws -> Result {
    let url = root.appendingPathComponent("PavementTests/Fixtures/Streets/\(photo).jpg")
    let img = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(url as CFURL, nil)!, 0, nil)!
    let rect = CGRect(x: box.minX * Double(img.width), y: box.minY * Double(img.height),
                      width: box.width * Double(img.width), height: box.height * Double(img.height)).integral
    let crop = img.cropping(to: rect)!
    let a = try classify(crop), b = try classify(mirrored(crop)), c = try classify(zoomed(crop))
    return Result(label: a.0, confidence: a.1,
                  agrees: b.0 == a.0 && c.0 == a.0 && b.1 >= agreementConfidence && c.1 >= agreementConfidence)
}

/// Same rule as CarIdentifier.identify.
func named(_ r: Result) -> String? { r.label != "other" && r.confidence >= minConfidence && r.agrees ? r.label : nil }

var failures = 0
func check(_ what: String, _ ok: Bool, _ detail: String) {
    print("\(ok ? "PASS" : "FAIL")  \(what)  (\(detail))")
    if !ok { failures += 1 }
}

// Different photos must not all get the same answer (catches a broken/degenerate model).
let answers = try [top("street01", CGRect(x: 0.44, y: 0.35, width: 0.15, height: 0.18)),   // Tahoe
                   top("street01", CGRect(x: 0.615, y: 0.38, width: 0.13, height: 0.235)), // Beetle
                   top("street15", CGRect(x: 0.2, y: 0.2, width: 0.5, height: 0.5))]        // sky
check("Different images give different answers", Set(answers.map(\.label)).count > 1, "\(answers.map(\.label))")

let tahoe = try top("street01", CGRect(x: 0.44, y: 0.35, width: 0.15, height: 0.18))
check("Unknown model (Chevy Tahoe) is not named", named(tahoe) == nil, "\(tahoe.label) \(tahoe.confidence)")

let sky = try top("street15", CGRect(x: 0.2, y: 0.2, width: 0.5, height: 0.5))
check("No car (Milky Way) is not named", named(sky) == nil, "\(sky.label) \(sky.confidence)")

// Known weakness, reported but not failing: the Beetle seen from behind.
let beetle = try top("street01", CGRect(x: 0.615, y: 0.38, width: 0.13, height: 0.235))
print("INFO  VW Beetle from behind → \(named(beetle) ?? "not named") (top guess \(beetle.label) \(beetle.confidence), views agree: \(beetle.agrees))")

exit(failures == 0 ? 0 : 1)
