//
//  GeminiService.swift
//  drivecompanion
//
//  Created by Revan Ferdinand on 02/07/26.
//

import Foundation

nonisolated enum GeminiError: Error, LocalizedError {
    case missingAPIKey
    case invalidResponse
    case requestFailed(Int)
    case rateLimited(retryAfter: TimeInterval?)
    case allModelsExhausted(summary: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "GEMINI_API_KEY not found. Check Secrets.xcconfig and the target's Info tab."
        case .invalidResponse:
            return "Gemini returned a response that could not be parsed."
        case .requestFailed(let code):
            return "Gemini request failed with HTTP \(code)."
        case .rateLimited(let retryAfter):
            if let retryAfter {
                return "Gemini rate limited the request (retry after \(Int(retryAfter))s)."
            }
            return "Gemini rate limited the request."
        case .allModelsExhausted(let summary):
            return summary
        }
    }
}

nonisolated enum ChatRole {
    case user
    case model
}

nonisolated struct ChatTurn {
    let role: ChatRole
    let text: String
}

nonisolated struct GeminiService {
    private let apiKey: String

    init() {
        guard
            let key = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String,
            !key.isEmpty,
            key != "YOUR_API_KEY_HERE"
        else {
            fatalError("GEMINI_API_KEY not found. Check Secrets.xcconfig and the target's Info tab.")
        }
        self.apiKey = key
    }

    func generateReply(model: String, systemInstruction: String, history: [ChatTurn]) async throws -> String {
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
            if code == 429 {
                let retryAfter = (response as? HTTPURLResponse)?
                    .value(forHTTPHeaderField: "Retry-After")
                    .flatMap(TimeInterval.init)
                throw GeminiError.rateLimited(retryAfter: retryAfter)
            }
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

    func streamReply(model: String, systemInstruction: String, history: [ChatTurn]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let url = URL(
                        string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?alt=sse&key=\(self.apiKey)"
                    )!

                    let contents: [[String: Any]] = history.map { turn in
                        let roleString = turn.role == .model ? "model" : "user"
                        return ["role": roleString, "parts": [["text": turn.text]]]
                    }

                    let body: [String: Any] = [
                        "system_instruction": ["parts": [["text": systemInstruction]]],
                        "contents": contents
                    ]

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (byteStream, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: GeminiError.invalidResponse)
                        return
                    }

                    if httpResponse.statusCode != 200 {
                        if httpResponse.statusCode == 429 {
                            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
                            continuation.finish(throwing: GeminiError.rateLimited(retryAfter: retryAfter))
                        } else {
                            continuation.finish(throwing: GeminiError.requestFailed(httpResponse.statusCode))
                        }
                        return
                    }

                    for try await line in byteStream.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonStr = String(line.dropFirst(6))
                        guard
                            let data = jsonStr.data(using: .utf8),
                            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                            let candidates = json["candidates"] as? [[String: Any]],
                            let content = candidates.first?["content"] as? [String: Any],
                            let parts = content["parts"] as? [[String: Any]],
                            let text = parts.first?["text"] as? String
                        else { continue }
                        continuation.yield(text)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
