//
//  WatchConnectivityManager.swift
//  drivercompanion Watch App
//
//  Created by Michelle Nathania on 05/07/26.
//

import Foundation
import WatchConnectivity
import Combine
import WatchKit

final class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var state: DrowsinessState = .alert
    
    private override init() {
        super.init()
        
        guard WCSession.isSupported() else {
            return
        }
        
        WCSession.default.delegate = self
        WCSession.default.activate()
    }
}

// MARK: Alert haptics on Watch
extension WatchConnectivityManager {
    
    // MARK: Drowsy
    private func playDrowsyHaptics() {
        WKInterfaceDevice.current().play(.directionUp)
    }
    
    // MARK: Microsleep
    // TODO: Make a function to detect gesture to stop the microsleep haptics -> ignore the camera state? :/ atau buat yang drowsy aja?
    private func playMicrosleepHaptics() {
        for i in 0..<10 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.6) {
                WKInterfaceDevice.current().play(.notification)
            }
        }
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        print("WCSession Activated: \(activationState.rawValue)")
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        print("Reachable: \(session.isReachable)")
    }
    
    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        print("Received:", message)
        
        DispatchQueue.main.async {
            if let action = message["action"] as? String {
                switch action {
                case "startDrivingSession": print("Driving session started")
                    
                default: break
                }
            }
            
            if let rawValue = message["drowsinessState"] as? String,
               let state = DrowsinessState(rawValue: rawValue)
            {
                let previousState = self.state
                self.state = state
                
                guard previousState != state else { return }
                
                switch state {
                case .drowsy:
                    self.playDrowsyHaptics()
                case .microsleep:
                    self.playMicrosleepHaptics()
                default: break
                }
            }
        }
    }
}
