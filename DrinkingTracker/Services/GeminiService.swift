import Foundation
import GoogleGenerativeAI

@Observable
final class GeminiService {

    static let shared = GeminiService()

    private let model: GenerativeModel
    private var chatSession: Chat?

    private init() {
        model = GenerativeModel(name: "gemini-1.5-flash", apiKey: Config.geminiAPIKey)
    }

    // MARK: - Stage Summary

    /// Generate a one-paragraph summary + recommendations for the current state.
    func stageSummary(
        bac: Double,
        stage: IntoxicationStage,
        heartRate: Double?,
        slurScore: Double?,
        blushScore: Double?
    ) async throws -> String {
        let hr = heartRate.map { "Heart rate: \(Int($0)) bpm." } ?? ""
        let slur = slurScore.map { "Slur detection score: \(String(format: "%.2f", $0)) / 1.0." } ?? ""
        let blush = blushScore.map { "Facial redness score: \(String(format: "%.2f", $0)) / 1.0." } ?? ""

        let prompt = """
        You are a harm-reduction assistant for an alcohol tracking app. \
        The user's current estimated BAC is \(String(format: "%.3f", bac))%. \
        Stage: \(stage.label). \(hr) \(slur) \(blush)

        In 2–3 sentences, summarise their current state and give 2 actionable safety recommendations. \
        Be concise, non-judgmental, and supportive.
        """

        let response = try await model.generateContent(prompt)
        return response.text ?? "Unable to generate summary."
    }

    // MARK: - Chat

    func startChat(context: String) {
        let systemContext = ModelContent(
            role: "user",
            parts: [.text("""
            You are a supportive harm-reduction assistant in a drinking tracker app. \
            The user's current context: \(context). \
            Answer their questions honestly, keep responses concise (under 100 words), \
            and always prioritise safety. Never encourage drinking more.
            """)]
        )
        chatSession = model.startChat(history: [systemContext])
    }

    func sendChatMessage(_ message: String) async throws -> String {
        guard let chat = chatSession else {
            startChat(context: "Unknown state")
            return try await sendChatMessage(message)
        }
        let response = try await chat.sendMessage(message)
        return response.text ?? "No response."
    }

    func resetChat() {
        chatSession = nil
    }
}
