//
//  GeminiService.swift
//  drivecompanion
//
//  Created by Revan Ferdinand on 02/07/26.
//

import Foundation

nonisolated enum GeminiError: Error, LocalizedError {
    case invalidResponse
    case requestFailed(Int)
    case rateLimited(retryAfter: TimeInterval?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Gemini returned a response that could not be parsed."
        case .requestFailed(let code):
            return "Gemini request failed with HTTP \(code)."
        case .rateLimited(let retryAfter):
            if let retryAfter {
                return "Gemini rate limited the request (retry after \(Int(retryAfter))s)."
            }
            return "Gemini rate limited the request."
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
    var isInternal: Bool = false
}

nonisolated struct GeminiService {
    static let model = "gemini-3.1-flash-lite"
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

    func streamReply(systemInstruction: String, history: [ChatTurn]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let url = URL(
                        string: "https://generativelanguage.googleapis.com/v1beta/models/\(Self.model):streamGenerateContent?alt=sse&key=\(self.apiKey)"
                    )!

                    let contents: [[String: Any]] = history.map { turn in
                        let roleString = turn.role == .model ? "model" : "user"
                        return ["role": roleString, "parts": [["text": turn.text]]]
                    }

                    let body: [String: Any] = [
                        "system_instruction": ["parts": [["text": systemInstruction]]],
                        "contents": contents,
                        "generationConfig": [
                            "temperature": 1.0,
                            "topP": 0.95
                        ]
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
