//
//  WatchConnectivityDelegate.swift
//  drivecompanion
//
//  Created by Michelle Nathania on 11/07/26.
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
    
    func sessionDidBecomeInactive(_ session: WCSession) {}
    
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    
    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        DispatchQueue.main.async {
            self.handleReceiveMessage(message)
        }
    }
}
