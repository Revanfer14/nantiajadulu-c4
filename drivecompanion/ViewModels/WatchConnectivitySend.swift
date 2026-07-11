//
//  WatchConnectivitySend.swift
//  drivecompanion
//
//  Created by Michelle Nathania on 11/07/26.
//

import Foundation
import WatchConnectivity

extension WatchConnectivityManager {
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
