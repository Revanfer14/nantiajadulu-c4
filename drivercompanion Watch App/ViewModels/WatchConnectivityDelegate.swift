//
//  WatchConnectivityDelegate.swift
//  drivercompanion Watch App
//
//  Created by Michelle Nathania on 07/07/26.
//

import Foundation
import WatchConnectivity

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
                    HapticManager.shared.play(.drowsy)
                case .microsleep:
                    HapticManager.shared.play(.microsleep)
                default: break
                }
            }
        }
    }
}
