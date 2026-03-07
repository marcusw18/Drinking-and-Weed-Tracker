import Vision
import UIKit
import CoreImage

/// On-device face analysis using Apple's Vision framework.
/// Detects blush (redness) and eye clarity from a still image.
enum FaceAnalyzer {

    struct FaceResult {
        let blushScore: Double      // 0.0 – 1.0 (higher = more red)
        let eyeOpennessScore: Double // 0.0 – 1.0 (lower = more closed)
    }

    static func analyze(image: UIImage) async throws -> FaceResult? {
        guard let cgImage = image.cgImage else { return nil }

        // Detect faces
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])

        guard let observation = request.results?.first else { return nil }

        let blush = try blushScore(cgImage: cgImage, observation: observation)
        let eyeOpen = eyeOpennessScore(observation: observation)

        return FaceResult(blushScore: blush, eyeOpennessScore: eyeOpen)
    }

    // MARK: - Blush (redness) Score

    private static func blushScore(cgImage: CGImage, observation: VNFaceObservation) throws -> Double {
        // Crop to face bounding box
        let box = observation.boundingBox
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        // VNFaceObservation bbox is normalized, origin at bottom-left
        let cropRect = CGRect(
            x: box.minX * width,
            y: (1 - box.maxY) * height,
            width: box.width * width,
            height: box.height * height
        ).integral

        guard let faceCG = cgImage.cropping(to: cropRect) else { return 0 }

        // Sample red channel average using CIImage
        let ciImage = CIImage(cgImage: faceCG)
        let extent = ciImage.extent
        let context = CIContext()

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(ciImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: extent.midX - 1, y: extent.midY - 1, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())

        let r = Double(bitmap[0]) / 255.0
        let g = Double(bitmap[1]) / 255.0
        let b = Double(bitmap[2]) / 255.0

        // Redness index: how much red dominates over green/blue
        let redness = max(0, (r - (g + b) / 2.0))
        return min(redness * 3.0, 1.0)   // scale to 0–1
    }

    // MARK: - Eye Openness

    private static func eyeOpennessScore(_ observation: VNFaceObservation) -> Double {
        guard let landmarks = observation.landmarks else { return 0.5 }

        var totalOpenness = 0.0
        var count = 0

        for eye in [landmarks.leftEye, landmarks.rightEye].compactMap({ $0 }) {
            let points = eye.normalizedPoints
            guard points.count >= 6 else { continue }

            // Vertical span of eye
            let ys = points.map { $0.y }
            let verticalSpan = (ys.max() ?? 0) - (ys.min() ?? 0)
            totalOpenness += verticalSpan
            count += 1
        }

        guard count > 0 else { return 0.5 }
        // Normalise: typical open eye has ~0.15 vertical span in landmark space
        return min(totalOpenness / Double(count) / 0.15, 1.0)
    }
}
