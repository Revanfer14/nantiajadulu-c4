//
//  DrowsinessDetector.swift
//  drivecompanion
//
//  Created by Filbert Naldo Wijaya on 02/07/26.
//

import Foundation

struct DrowsinessSnapshot {
    let perclos: Double
    let closedDuration: TimeInterval
    let isMicrosleep: Bool
    let headDropDuration: TimeInterval
    let jawOpenDuration: TimeInterval
    let state: DrowsinessState
}

final class DrowsinessDetector {
    // PERCLOS (from EAR) - continuous 30 seconds EAR history buffer to detect drowsiness
    private var earHistory: [(timestamp: Date, ear: Double)] = []
    private let perclosWindow: TimeInterval = 30
    private let earDrowsyThreshold: Double = 0.75
    private let perclosFadingThreshold: Double = 0.15

    // CLOSDUR - for catching an actual microsleep as it happens
    private var eyeClosedSince: Date? = nil
    private let earClosedThreshold: Double = 0.4
    private let microsleepThreshold: TimeInterval = 2.0

    // HEAD DROP
    private var headDroppedSince: Date? = nil
    private let headDropThreshold: TimeInterval = 1.0
    private let pitchDropThreshold: Double = 0.2

    // YAWN
    private var jawOpenSince: Date? = nil
    private let jawOpenThreshold: Double = 0.8
    private let yawnThreshold: TimeInterval = 4.0

    init() {
        seedEarHistory()
    }

    // DETECTION
    func update(eyeOpenness: Double, jawOpen: Double, pitch: Double) -> DrowsinessSnapshot {
        let perclos = updatePerclos(with: eyeOpenness)
        let (closedDuration, isMicrosleep) = updateClosedDuration(with: eyeOpenness)
        let headDropDuration = updateHeadDropDuration(with: pitch)
        let jawOpenDuration = updateJawOpenDuration(with: jawOpen)

        let headDropped = headDropDuration >= headDropThreshold
        let yawn = jawOpenDuration >= yawnThreshold

        let state: DrowsinessState
        if isMicrosleep {
            state = .microsleep
        } else if perclos > perclosFadingThreshold || (headDropped && perclos > perclosFadingThreshold * 0.5) || yawn {
            state = .drowsy
        } else {
            state = .alert
        }

        return DrowsinessSnapshot(perclos: perclos,
                                  closedDuration: closedDuration,
                                  isMicrosleep: isMicrosleep,
                                  headDropDuration: headDropDuration,
                                  jawOpenDuration: jawOpenDuration,
                                  state: state)
    }

    func reset() {
        eyeClosedSince = nil
        headDroppedSince = nil
        jawOpenSince = nil
    }

    // dummy seed to prevent cold-start
    private func seedEarHistory() {
        let now = Date()
        let sampleCount = 1800 // 60fps x 30sec
        let dummyEar = 0.95
        earHistory = (0..<sampleCount).map { i in
            let secondsAgo = perclosWindow * Double(sampleCount - i) / Double(sampleCount)
            return (timestamp: now.addingTimeInterval(-secondsAgo), ear: dummyEar)
        }
    }

    private func updatePerclos(with ear: Double) -> Double {
        let now = Date()
        earHistory.append((timestamp: now, ear: ear)) // append new sample
        earHistory.removeAll { now.timeIntervalSince($0.timestamp) > perclosWindow } // remove samples older than 30 secs from now
        guard !earHistory.isEmpty else { return 0 }
        let closedCount = earHistory.filter { $0.ear < earDrowsyThreshold }.count
        return Double(closedCount) / Double(earHistory.count)
    }

    private func updateClosedDuration(with ear: Double) -> (TimeInterval, Bool) {
        let now = Date()
        let duration: TimeInterval
        if ear < earClosedThreshold {
            if eyeClosedSince == nil { eyeClosedSince = now }
            duration = now.timeIntervalSince(eyeClosedSince!)
        } else {
            eyeClosedSince = nil
            duration = 0
        }
        return (duration, duration >= microsleepThreshold)
    }

    private func updateHeadDropDuration(with pitch: Double) -> TimeInterval {
        let now = Date()
        if pitch > pitchDropThreshold {
            if headDroppedSince == nil { headDroppedSince = now }
            return now.timeIntervalSince(headDroppedSince!)
        } else {
            headDroppedSince = nil
            return 0
        }
    }

    private func updateJawOpenDuration(with jawOpen: Double) -> TimeInterval {
        let now = Date()
        if jawOpen >= jawOpenThreshold {
            if jawOpenSince == nil { jawOpenSince = now }
            return now.timeIntervalSince(jawOpenSince!)
        } else {
            jawOpenSince = nil
            return 0
        }
    }
}
