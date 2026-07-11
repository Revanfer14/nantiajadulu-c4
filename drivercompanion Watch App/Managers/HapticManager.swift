//
//  HapticManager.swift
//  drivercompanion Watch App
//
//  Created by Michelle Nathania on 07/07/26.
//

import Foundation
import WatchKit

// MARK: Alert haptics on Watch
final class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    enum HapticType {
        case drowsy
        case microsleep
    }
    
    func play(_ type: HapticType) {
        switch type {
        case .drowsy: playDrowsy()
        case .microsleep: playMicrosleep()
        }
    }
}

// MARK: Haptic function
private extension HapticManager {
    func playDrowsy() {
        WKInterfaceDevice.current().play(.directionUp)
    }
    
    func playMicrosleep() {
        for i in 0..<10 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.6) {
                WKInterfaceDevice.current().play(.notification)
            }
        }
    }
}
