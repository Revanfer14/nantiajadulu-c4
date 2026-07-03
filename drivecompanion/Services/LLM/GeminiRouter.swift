//
//  GeminiRouter.swift
//  drivecompanion
//
//  Created by Revan Ferdinand on 02/07/26.
//

import CryptoKit
import Foundation
import os

nonisolated struct GeminiModelConfig {
    let name: String
    let rpm: Int
    let tpm: Int?
    let rpd: Int
}

nonisolated enum GeminiRouterConfig {
    static let fallbackChain: [GeminiModelConfig] = [
        GeminiModelConfig(name: "gemini-3.5-flash",      rpm: 5,  tpm: 250_000, rpd: 20),
        GeminiModelConfig(name: "gemini-3-flash",        rpm: 5,  tpm: 250_000, rpd: 20),
        GeminiModelConfig(name: "gemini-2.5-flash",      rpm: 5,  tpm: 250_000, rpd: 20),
        GeminiModelConfig(name: "gemini-2.5-flash-lite", rpm: 10, tpm: 250_000, rpd: 20),
        GeminiModelConfig(name: "gemini-3.1-flash-lite", rpm: 15, tpm: 250_000, rpd: 500),
        GeminiModelConfig(name: "gemma-4-26b",           rpm: 15, tpm: nil,     rpd: 1_500),
        GeminiModelConfig(name: "gemma-4-31b",           rpm: 15, tpm: nil,     rpd: 1_500),
    ]

    static let cacheTTL: TimeInterval = 3600
    
    static let rpmSafetyBuffer = 1

    static let retriesPerModel = 2

    static let retryDelays: [TimeInterval] = [1.0, 2.0]

    static let persistentRateLimitCooldown: TimeInterval = 60
}

nonisolated struct GeminiReply {
    let text: String
    let modelName: String
    let usedFallback: Bool
    let fromCache: Bool
}

nonisolated struct GeminiUsageSnapshot {
    nonisolated struct ModelUsage {
        let name: String
        let rpmUsed: Int
        let rpmCap: Int
        let rpdUsed: Int
        let rpdLimit: Int
        let coolingDown: Bool
    }

    let models: [ModelUsage]
    let cacheHits: Int
    let cacheEntries: Int
}

private nonisolated struct GeminiCacheEntry {
    let reply: GeminiReply
    let insertedAt: Date
}

private nonisolated struct ModelUsageTracker {
    private var requestTimestamps: [Date] = []
    private var dailyCount = 0
    private var dailyKey = DateComponents()
    private var cooldownUntil: Date?

    private static let pacificCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }()

    mutating func dailyUnavailableReason(config: GeminiModelConfig, now: Date = Date()) -> String? {
        refresh(now: now)
        if let until = cooldownUntil {
            if now < until {
                return "cooling down \(Int(until.timeIntervalSince(now)))s after persistent rate limiting"
            }
            cooldownUntil = nil
        }
        if dailyCount >= config.rpd {
            return "daily quota exhausted (\(dailyCount)/\(config.rpd) RPD, resets midnight Pacific)"
        }
        return nil
    }

    mutating func rpmDelay(cap: Int, now: Date = Date()) -> TimeInterval {
        refresh(now: now)
        guard requestTimestamps.count >= cap, let oldest = requestTimestamps.first else { return 0 }
        return max(0.1, 60.05 - now.timeIntervalSince(oldest))
    }

    mutating func recordRequest(now: Date = Date()) {
        refresh(now: now)
        requestTimestamps.append(now)
        dailyCount += 1
    }

    mutating func startCooldown(_ interval: TimeInterval, now: Date = Date()) {
        cooldownUntil = now.addingTimeInterval(interval)
    }

    mutating func usage(config: GeminiModelConfig, now: Date = Date()) -> GeminiUsageSnapshot.ModelUsage {
        refresh(now: now)
        return GeminiUsageSnapshot.ModelUsage(
            name: config.name,
            rpmUsed: requestTimestamps.count,
            rpmCap: max(1, config.rpm - GeminiRouterConfig.rpmSafetyBuffer),
            rpdUsed: dailyCount,
            rpdLimit: config.rpd,
            coolingDown: cooldownUntil.map { now < $0 } ?? false
        )
    }

    private mutating func refresh(now: Date) {
        requestTimestamps.removeAll { now.timeIntervalSince($0) >= 60 }
        let key = Self.pacificCalendar.dateComponents([.year, .month, .day], from: now)
        if key != dailyKey {
            dailyKey = key
            dailyCount = 0
        }
    }
}

// The single entry point for all Gemini calls. Request flow:
// cache check → model selection (RPD/cooldown) → RPM queue → API call with
// retry → on persistent quota failure, next model in the chain.

actor GeminiRouter {
    private let service = GeminiService()
    private var trackers: [String: ModelUsageTracker] = [:]
    private var cache: [String: GeminiCacheEntry] = [:]
    private var cacheHitCount = 0
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "drivecompanion",
        category: "GeminiRouter"
    )

    func generateReply(systemInstruction: String, history: [ChatTurn]) async throws -> GeminiReply {
        let chain = GeminiRouterConfig.fallbackChain
        guard let primary = chain.first else {
            throw GeminiError.allModelsExhausted(summary: "Gemini fallback chain is empty — check GeminiRouterConfig")
        }

        // Layer 1: response cache.
        let cacheKey = Self.cacheKey(systemInstruction: systemInstruction, history: history)
        if let entry = cache[cacheKey] {
            if Date().timeIntervalSince(entry.insertedAt) < GeminiRouterConfig.cacheTTL {
                cacheHitCount += 1
                logger.info("Cache hit — reusing \(entry.reply.modelName, privacy: .public) response, no API call")
                return GeminiReply(
                    text: entry.reply.text,
                    modelName: entry.reply.modelName,
                    usedFallback: entry.reply.usedFallback,
                    fromCache: true
                )
            }
            cache[cacheKey] = nil
        }

        // Layer 3: walk the fallback chain; layers 2 and 4 apply per model.
        for config in chain {
            let model = config.name

            if let reason = withTracker(model, { $0.dailyUnavailableReason(config: config) }) {
                logger.info("Skipping \(model, privacy: .public): \(reason, privacy: .public)")
                continue
            }

            var attempt = 0
            attemptLoop: while true {
                // Layer 2: RPM budget — queue until a slot opens, never fall
                // back over a momentary burst.
                try await waitForRPMSlot(config)

                // The daily quota may have run out while this request was queued.
                if let reason = withTracker(model, { $0.dailyUnavailableReason(config: config) }) {
                    logger.info("Leaving \(model, privacy: .public) after queueing: \(reason, privacy: .public)")
                    break attemptLoop
                }

                withTracker(model) { $0.recordRequest() }
                do {
                    let text = try await service.generateReply(
                        model: model,
                        systemInstruction: systemInstruction,
                        history: history
                    )
                    return cacheAndReturn(text: text, model: model, primary: primary, cacheKey: cacheKey)
                } catch let error where Self.isTransient(error) {
                    // Layer 4: retry the same model before declaring it exhausted.
                    if attempt < GeminiRouterConfig.retriesPerModel {
                        let delay = Self.retryDelay(for: error, attempt: attempt)
                        logger.info("\(model, privacy: .public) rate limited/unavailable, retrying in \(delay, privacy: .public)s (attempt \(attempt + 1, privacy: .public)/\(GeminiRouterConfig.retriesPerModel, privacy: .public))")
                        try await Task.sleep(for: .seconds(delay))
                        attempt += 1
                    } else {
                        withTracker(model) { $0.startCooldown(GeminiRouterConfig.persistentRateLimitCooldown) }
                        logger.warning("\(model, privacy: .public) still failing after \(GeminiRouterConfig.retriesPerModel, privacy: .public) retries — cooling down \(GeminiRouterConfig.persistentRateLimitCooldown, privacy: .public)s, moving to next model")
                        break attemptLoop
                    }
                }
            }
        }

        let summary = exhaustionSummary()
        logger.error("\(summary, privacy: .public)")
        throw GeminiError.allModelsExhausted(summary: summary)
    }

    func clearCache() {
        cache.removeAll()
        logger.info("Response cache cleared")
    }

    func usageSnapshot() -> GeminiUsageSnapshot {
        let models = GeminiRouterConfig.fallbackChain.map { config in
            withTracker(config.name) { $0.usage(config: config) }
        }
        return GeminiUsageSnapshot(models: models, cacheHits: cacheHitCount, cacheEntries: cache.count)
    }

    func logUsageSummary() {
        let snapshot = usageSnapshot()
        var lines = ["Gemini usage — cache: \(snapshot.cacheHits) hits, \(snapshot.cacheEntries) entries"]
        for model in snapshot.models {
            lines.append("  \(model.name): RPM \(model.rpmUsed)/\(model.rpmCap), RPD \(model.rpdUsed)/\(model.rpdLimit)\(model.coolingDown ? " [cooldown]" : "")")
        }
        logger.info("\(lines.joined(separator: "\n"), privacy: .public)")
    }

    // MARK: Internals

    private func waitForRPMSlot(_ config: GeminiModelConfig) async throws {
        let cap = max(1, config.rpm - GeminiRouterConfig.rpmSafetyBuffer)
        while true {
            let delay = withTracker(config.name) { $0.rpmDelay(cap: cap) }
            guard delay > 0 else { return }
            logger.info("\(config.name, privacy: .public) at RPM cap \(cap, privacy: .public)/min — request queued for \(String(format: "%.1f", delay), privacy: .public)s")
            try await Task.sleep(for: .seconds(delay))
        }
    }

    private func cacheAndReturn(text: String, model: String, primary: GeminiModelConfig, cacheKey: String) -> GeminiReply {
        let usedFallback = model != primary.name
        if usedFallback {
            logger.warning("Fallback model \(model, privacy: .public) answered instead of primary \(primary.name, privacy: .public) — responses may differ in style/capability")
        }
        let reply = GeminiReply(text: text, modelName: model, usedFallback: usedFallback, fromCache: false)
        pruneExpiredCacheEntries()
        cache[cacheKey] = GeminiCacheEntry(reply: reply, insertedAt: Date())
        return reply
    }

    private func pruneExpiredCacheEntries(now: Date = Date()) {
        cache = cache.filter { now.timeIntervalSince($0.value.insertedAt) < GeminiRouterConfig.cacheTTL }
    }

    private func exhaustionSummary() -> String {
        let states = usageSnapshot().models
            .map { "\($0.name) RPD \($0.rpdUsed)/\($0.rpdLimit)\($0.coolingDown ? " (cooldown)" : "")" }
            .joined(separator: ", ")
        return "All models in the Gemini fallback chain are exhausted — \(states). Daily quotas reset at midnight Pacific time."
    }

    private func withTracker<T>(_ model: String, _ body: (inout ModelUsageTracker) -> T) -> T {
        var tracker = trackers[model] ?? ModelUsageTracker()
        let result = body(&tracker)
        trackers[model] = tracker
        return result
    }

    private static func cacheKey(systemInstruction: String, history: [ChatTurn]) -> String {
        var hasher = SHA256()
        func absorb(_ string: String) {
            hasher.update(data: Data("\(string.utf8.count):".utf8))
            hasher.update(data: Data(string.utf8))
        }
        absorb(systemInstruction)
        for turn in history {
            absorb(turn.role == .model ? "model" : "user")
            absorb(turn.text)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func isTransient(_ error: Error) -> Bool {
        switch error {
        case GeminiError.rateLimited:
            return true
        case GeminiError.requestFailed(let code) where (500...599).contains(code):
            return true
        default:
            return false
        }
    }

    private static func retryDelay(for error: Error, attempt: Int) -> TimeInterval {
        if case GeminiError.rateLimited(let retryAfter) = error, let retryAfter {
            return retryAfter
        }
        let delays = GeminiRouterConfig.retryDelays
        return attempt < delays.count ? delays[attempt] : delays.last ?? 1.0
    }
}
