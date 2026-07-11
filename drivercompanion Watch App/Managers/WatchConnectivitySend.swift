//
//  WatchConnectivitySend.swift
//  drivercompanion Watch App
//
//  Created by Michelle Nathania on 11/07/26.
//

import Foundation
import WatchConnectivity

extension WatchConnectivityManager {
    func sendDismissDrowsy() {
        guard WCSession.default.isReachable else {
            print("Phone not reachable")
            return
        }
        
        WCSession.default.sendMessage(
            [
                "type": "event",
                "event": "dismissDrowsy"
            ],
            replyHandler: nil
        ) {
            error in
            print("Error: \(error.localizedDescription)")
        }
        
        print("Dismissed")
    }
}
