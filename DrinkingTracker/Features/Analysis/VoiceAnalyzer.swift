import Foundation
import AVFoundation

/// Handles voice recording and slur detection analysis.
/// Works with local iPhone recording or audio from the Watch.
actor VoiceAnalyzer {

    enum VoiceAnalyzerError: LocalizedError {
        case microphoneNotAvailable
        case recordingFailed(String)
        case encodingFailed
        case analysisFailed(String)

        var errorDescription: String? {
            switch self {
            case .microphoneNotAvailable:
                return "Microphone is not available"
            case .recordingFailed(let msg):
                return "Recording failed: \(msg)"
            case .encodingFailed:
                return "Failed to encode audio"
            case .analysisFailed(let msg):
                return "Analysis failed: \(msg)"
            }
        }
    }

    nonisolated static let shared = VoiceAnalyzer()

    private var audioEngine: AVAudioEngine?
    private var recordingURL: URL?
    private var audioFile: AVAudioFile?

    nonisolated private init() {}

    // MARK: - Permissions

    /// Request microphone permission and return whether access was granted.
    nonisolated func requestMicrophonePermission() async -> Bool {
        let status = AVAudioApplication.shared.recordPermission
        switch status {
        case .denied, .undetermined:
            let granted = await AVAudioApplication.shared.requestRecordPermission()
            return granted
        case .granted:
            return true
        @unknown default:
            return false
        }
    }

    // MARK: - Recording

    /// Record audio for the specified duration and save to a temporary file.
    /// - Parameter duration: Length of recording in seconds (default: 10)
    /// - Returns: URL of the recorded .m4a file
    func recordAudio(duration: TimeInterval = 10) async throws -> URL {
        guard AVAudioApplication.shared.recordPermission == .granted else {
            throw VoiceAnalyzerError.microphoneNotAvailable
        }

        let engine = AVAudioEngine()
        self.audioEngine = engine

        let tempDir = FileManager.default.temporaryDirectory
        let filename = "voice_\(UUID().uuidString).m4a"
        let outputURL = tempDir.appendingPathComponent(filename)

        let inputNode = engine.inputNode
        inputNode.removeTap(onBus: 0)

        let format = inputNode.outputFormat(forBus: 0)

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVEncoderBitRateKey: 128000
        ]

        guard let audioFile = try? AVAudioFile(forWriting: outputURL, settings: outputSettings) else {
            throw VoiceAnalyzerError.encodingFailed
        }

        // Avoid actor isolation issues with closure
        let fileRef = audioFile

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            do {
                try fileRef.write(from: buffer)
            } catch {
                print("Error writing audio: \(error)")
            }
        }

        do {
            try engine.start()
        } catch {
            throw VoiceAnalyzerError.recordingFailed(error.localizedDescription)
        }

        self.recordingURL = outputURL
        self.audioFile = audioFile

        try await Task.sleep(for: .seconds(duration))

        inputNode.removeTap(onBus: 0)
        engine.stop()

        return outputURL
    }

    // MARK: - Analysis

    /// Analyze an audio file for slurring.
    /// - Parameter audioURL: Local file URL of the audio (.m4a)
    /// - Returns: Slur score from 0.0 to 1.0
    func analyzeAudio(audioURL: URL) async throws -> Double {
        let response = try await VultureService.shared.analyzeVoice(audioURL: audioURL)
        return response.slurScore
    }

    /// Record and analyze audio in one call.
    /// - Parameter duration: Length of recording in seconds
    /// - Returns: Slur score from 0.0 to 1.0
    func recordAndAnalyze(duration: TimeInterval = 10) async throws -> Double {
        let audioURL = try await recordAudio(duration: duration)
        return try await analyzeAudio(audioURL: audioURL)
    }

    // MARK: - Cleanup

    /// Clean up recording resources and remove temporary file.
    func cleanup() {
        audioEngine?.stop()
        audioEngine = nil
        audioFile = nil
        
        if let recordingURL = recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        recordingURL = nil
    }
