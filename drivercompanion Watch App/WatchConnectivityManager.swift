//
//  WatchConnectivityManager.swift
//  drivercompanion Watch App
//
//  Created by Michelle Nathania on 05/07/26.
//

import Foundation
import WatchConnectivity

final class WatchConnectivityManager: NSObject {
    static let shared = WatchConnectivityManager()
    
    private override init() {
        super.init()
        
        guard WCSession.isSupported() else {
            return
        }
        
        WCSession.default.delegate = self
        WCSession.default.activate()
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
        didReceiveMessage message: [String: Any],
    ) {
        print("Message received: \(message)")
        
        guard let action = message["action"] as? String else {
            return
        }
        
        switch action {
        case "startDrivingSession":
            print("Driving session started")
            
        default:
            break
        }
    }
}
