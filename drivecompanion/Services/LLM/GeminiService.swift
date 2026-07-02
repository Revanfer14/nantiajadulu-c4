//
//  GeminiService.swift
//  drivecompanion
//
//  Created by Revan Ferdinand on 02/07/26.
//

import Foundation

enum GeminiError: Error {
    case missingAPIKey
    case invalidResponse
    case requestFailed(Int)
}

enum ChatRole {
    case user
    case model
}

struct ChatTurn {
    let role: ChatRole
    let text: String
}

struct GeminiService {
    private let apiKey: String
    private let model: String

    var modelName: String { model }

    init(model: String = "gemini-3.5-flash") {
        guard
            let key = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String,
            !key.isEmpty,
            key != "YOUR_API_KEY_HERE"
        else {
            fatalError("GEMINI_API_KEY not found. Check Secrets.xcconfig and the target's Info tab.")
        }
        self.apiKey = key
        self.model = model
    }

    func generateReply(systemInstruction: String, history: [ChatTurn]) async throws -> String {
        let url = URL(
            string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        )!

        let contents: [[String: Any]] = history.map { turn in
            let roleString = turn.role == .model ? "model" : "user"
            return ["role": roleString, "parts": [["text": turn.text]]]
        }

        let body: [String: Any] = [
            "system_instruction": [
                "parts": [["text": systemInstruction]]
            ],
            "contents": contents
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw GeminiError.requestFailed(code)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let content = candidates.first?["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let text = parts.first?["text"] as? String
        else {
            throw GeminiError.invalidResponse
        }

        return text
    }
}
