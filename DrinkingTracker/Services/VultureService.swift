import Foundation

struct VultureResponse: Codable {
    let transcript: String
    let slurScore: Double   // 0.0 – 1.0

    enum CodingKeys: String, CodingKey {
        case transcript
        case slurScore = "slur_score"
    }
}

final class VultureService {

    static let shared = VultureService()
    private init() {}

    /// POST audio file to the Vulture server and return the slur score.
    /// - Parameter audioURL: local file URL of the recorded .m4a clip
    func analyzeVoice(audioURL: URL) async throws -> VultureResponse {
        let endpoint = URL(string: "\(Config.vultureServerURL)/analyze/voice")!

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let audioData = try Data(contentsOf: audioURL)
        var body = Data()

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"recording.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(VultureResponse.self, from: data)
    }

    /// Health-check the Vulture server.
    func isReachable() async -> Bool {
        guard let url = URL(string: "\(Config.vultureServerURL)/health") else { return false }
        let request = URLRequest(url: url, timeoutInterval: 3)
        return (try? await URLSession.shared.data(for: request)) != nil
    }
}
