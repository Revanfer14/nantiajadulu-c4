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
    @Published private(set) var detectedGesture: MotionGesture?
    
    static let shared = MotionManager()
    
    private let motionManager = CMMotionManager()
    private let detector = MotionGestureDetector()
    
    private init() {}
    
    func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device motion is not available")
            return
        }
        
        print("Start listening")
        motionManager.deviceMotionUpdateInterval = 1.0 / 50.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self else { return }
            
            if let error {
                print(error.localizedDescription)
                return
            }
            
            guard let motion else { return }
            let rotationX = motion.rotationRate.x
            if let gesture = detector.process(rotationX: rotationX) {
                self.detectedGesture = gesture
            }
        }
//        motionManager.startDeviceMotionUpdates(to: .main) {
//            motion, error in
//            guard let motion else { return }
//            
//            if motion.rotationRate.x > 10 || motion.rotationRate.x < -10 {
//                print("Rotation x: ", motion.rotationRate.x)
//                print("Rotation y: ", motion.rotationRate.y)
//                print("Rotation z: ", motion.rotationRate.z)
//                print()
//            }
//        }
        
    }
    
    func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
        detector.reset()
        detectedGesture = nil
    }
    
    func clearGesture() {
        detectedGesture = nil
    }
}
