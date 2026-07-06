//
//  WatchConnectivityManager.swift
//  drivecompanion
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
    
    // MARK: Start driving session
    func startDrivingSession() {
        guard WCSession.default.isReachable else {
            print("Cannot send state. Watch is not reachable")
            return
        }
        
        WCSession.default.sendMessage(
            ["action": "startDrivingSession"],
            replyHandler: nil
        ) {
            error in
            print("Failed to send message: \(error.localizedDescription)")
        }
        
        print("Start session in Watch")
    }
    
    // MARK: Send drowsiness state
    func sendDrowsinessState(_ state: DrowsinessState) {
        guard WCSession.default.isReachable else {
            print("Cannot send state. Watch is not reachable")
            return
        }
        
        WCSession.default.sendMessage(
            ["drowsinessState": state.rawValue],
            replyHandler: nil
        ) {
            error in
            print("Failed to send message: \(error.localizedDescription)")
        }
        
        print("State sent: \(state.rawValue)")
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
    
    func sessionDidBecomeInactive(_ session: WCSession) {}
    
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
