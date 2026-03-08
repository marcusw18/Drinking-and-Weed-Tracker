import Foundation

/// Physiological + visual scan results from a single scan session.
/// Populated by SmartSpectraSwiftSDK (heart rate, focus) and Vision (face signals).
struct ScanResults {
    var heartRate: Double?          // bpm — elevated HR suggests intoxication
    var focusScore: Double?         // 0.0–1.0 — low = impaired attention (HRV-derived)
    var redEyeScore: Double?        // 0.0–1.0 — sclera redness
    var droopyEyelidScore: Double?  // 0.0–1.0 — 1 = fully droopy/closed
    var flushFaceScore: Double?     // 0.0–1.0 — cheek redness
}
