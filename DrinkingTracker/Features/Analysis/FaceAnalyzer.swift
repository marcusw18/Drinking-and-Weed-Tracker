import Vision
import UIKit
import CoreImage

/// On-device face analysis using Apple's Vision framework.
/// Detects flush (cheek redness), red eyes (sclera redness), and droopy eyelids.
enum FaceAnalyzer {

    struct FaceResult {
        let blushScore: Double          // 0.0–1.0  cheek redness / flushed face
        let redEyeScore: Double         // 0.0–1.0  sclera redness
        let eyeOpennessScore: Double    // 0.0–1.0  1 = fully open, 0 = closed/droopy
    }

    static func analyze(image: UIImage) async throws -> FaceResult? {
        guard let cgImage = image.cgImage else { return nil }

        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])

        guard let observation = request.results?.first else { return nil }

        let blush   = try blushScore(cgImage: cgImage, observation: observation)
        let redEye  = try redEyeScore(cgImage: cgImage, observation: observation)
        let eyeOpen = eyeOpennessScore(observation: observation)

        return FaceResult(
            blushScore: blush,
            redEyeScore: redEye,
            eyeOpennessScore: eyeOpen
        )
    }

    // MARK: - Flushed Face (cheek redness)

    /// Samples pixels from the left and right cheek regions and measures red dominance.
    private static func blushScore(cgImage: CGImage, observation: VNFaceObservation) throws -> Double {
        let box    = observation.boundingBox
        let width  = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        // Cheek regions: ~30% in from each side, ~55–70% down the face
        let cheekY      = (1 - (box.minY + box.height * 0.45)) * height
        let cheekHeight = box.height * 0.15 * height
        let cheekWidth  = box.width * 0.22 * width

        let leftCheek  = CGRect(x: box.minX * width,
                                y: cheekY,
                                width: cheekWidth,
                                height: cheekHeight).integral
        let rightCheek = CGRect(x: (box.maxX * width) - cheekWidth,
                                y: cheekY,
                                width: cheekWidth,
                                height: cheekHeight).integral

        let leftRedness  = sampleRedness(cgImage: cgImage, rect: leftCheek)
        let rightRedness = sampleRedness(cgImage: cgImage, rect: rightCheek)

        return min((leftRedness + rightRedness) / 2.0 * 3.0, 1.0)
    }

    // MARK: - Red Eyes (sclera redness)

    /// Samples pixels from the eye regions and measures red channel dominance in the sclera.
    private static func redEyeScore(cgImage: CGImage, observation: VNFaceObservation) throws -> Double {
        guard let landmarks = observation.landmarks else { return 0 }
        let width  = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let box    = observation.boundingBox

        var scores: [Double] = []

        for eye in [landmarks.leftEye, landmarks.rightEye].compactMap({ $0 }) {
            let pts = eye.normalizedPoints
            guard pts.count >= 4 else { continue }

            // Convert normalized landmark points to image coords
            let xs = pts.map { box.minX * width  + $0.x * box.width  * width  }
            let ys = pts.map { (1 - (box.minY + $0.y * box.height)) * height }

            let minX = xs.min() ?? 0; let maxX = xs.max() ?? 0
            let minY = ys.min() ?? 0; let maxY = ys.max() ?? 0

            let eyeRect = CGRect(x: minX, y: minY,
                                 width: max(maxX - minX, 1),
                                 height: max(maxY - minY, 1)).integral

            scores.append(sampleRedness(cgImage: cgImage, rect: eyeRect))
        }

        guard !scores.isEmpty else { return 0 }
        return min(scores.reduce(0, +) / Double(scores.count) * 4.0, 1.0)
    }

    // MARK: - Droopy Eyelids (eye openness via aspect ratio)

    /// Eye Aspect Ratio (EAR): ratio of vertical to horizontal eye span.
    /// Typical open eye ≈ 0.25–0.35; droopy/closed < 0.18.
    private static func eyeOpennessScore(_ observation: VNFaceObservation) -> Double {
        guard let landmarks = observation.landmarks else { return 0.5 }

        var ears: [Double] = []

        for eye in [landmarks.leftEye, landmarks.rightEye].compactMap({ $0 }) {
            let pts = eye.normalizedPoints
            guard pts.count >= 6 else { continue }

            let xs = pts.map { $0.x }
            let ys = pts.map { $0.y }
            let horizontalSpan = (xs.max() ?? 0) - (xs.min() ?? 0)
            let verticalSpan   = (ys.max() ?? 0) - (ys.min() ?? 0)
            guard horizontalSpan > 0 else { continue }

            let ear = verticalSpan / horizontalSpan
            ears.append(ear)
        }

        guard !ears.isEmpty else { return 0.5 }
        let avgEAR = ears.reduce(0, +) / Double(ears.count)
        // Normalise: 0.30 = fully open → 1.0, 0.05 = fully closed → 0.0
        return min(max((avgEAR - 0.05) / 0.25, 0), 1.0)
    }

    // MARK: - Pixel Sampling Helper

    private static func sampleRedness(cgImage: CGImage, rect: CGRect) -> Double {
        let clampedRect = rect.intersection(CGRect(x: 0, y: 0,
                                                   width: CGFloat(cgImage.width),
                                                   height: CGFloat(cgImage.height)))
        guard !clampedRect.isNull, !clampedRect.isEmpty,
              let cropped = cgImage.cropping(to: clampedRect) else { return 0 }

        let ciImage = CIImage(cgImage: cropped)
        let ctx     = CIContext()
        var bitmap  = [UInt8](repeating: 0, count: 4)
        ctx.render(ciImage,
                   toBitmap: &bitmap,
                   rowBytes: 4,
                   bounds: CGRect(x: ciImage.extent.midX - 1, y: ciImage.extent.midY - 1,
                                  width: 1, height: 1),
                   format: .RGBA8,
                   colorSpace: CGColorSpaceCreateDeviceRGB())

        let r = Double(bitmap[0]) / 255.0
        let g = Double(bitmap[1]) / 255.0
        let b = Double(bitmap[2]) / 255.0
        return max(0, r - (g + b) / 2.0)
    }
}
