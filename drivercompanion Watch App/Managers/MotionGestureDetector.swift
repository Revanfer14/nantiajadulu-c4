//
//  MotionGestureDetector.swift
//  drivercompanion Watch App
//
//  Created by Michelle Nathania on 11/07/26.
//

import Foundation

final class MotionGestureDetector {
    private enum gestureState {
        case idle
        case waitingForNeutral
        case cooldown
    }
    
    private var state: gestureState = .idle
    
    private let flickThreshold = 10.0
    private let neutralThreshold = 15.0
    private let cooldownDuration = 1.0
    
    private var cooldownUntil: Date?
    
    func process (rotationX: Double) -> MotionGesture? {
        switch state {
        case .idle:
            if rotationX > flickThreshold {
                state = .waitingForNeutral
            }
            
        case .waitingForNeutral:
            if abs(rotationX) < neutralThreshold {
                print("Waiting for neutral")
                state = .cooldown
                cooldownUntil = Date().addingTimeInterval(cooldownDuration)
                return .dismissDrowsy
            }
            
        case .cooldown:
            if let cooldownUntil,
               Date() > cooldownUntil {
                state = .idle
                self.cooldownUntil = nil
            }
        }
        return nil
    }
    
    func reset() {
        state = .idle
        cooldownUntil = nil
    }
}
