//
//  MotionManager.swift
//  drivercompanion Watch App
//
//  Created by Michelle Nathania on 07/07/26.
//

import Foundation
import CoreMotion
import Combine

final class MotionManager: ObservableObject {
    static let shared = MotionManager()
    
    private let motionManager = CMMotionManager()
    
    private init() {}
    
    func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device motion is not available")
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 50.0
        motionManager.startDeviceMotionUpdates(to: .main) {
            motion, error in
            guard let motion else { return }
            
            print("Rotation x: ", motion.rotationRate.x)
            print("Rotation y: ", motion.rotationRate.y)
            print("Rotation z: ", motion.rotationRate.z)
            print()
        }
        
    }
    
    func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
}
