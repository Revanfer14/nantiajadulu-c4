//
//  WatchConnectivityReceive.swift
//  drivecompanion
//
//  Created by Michelle Nathania on 11/07/26.
//

import Foundation
import WatchConnectivity

extension WatchConnectivityManager {
    func handleReceiveMessage(_ message: [String: Any]) {
        print("Received: \(message)")
        
        guard let type = message["type"] as? String else {
            return
        }
        
        switch type {
        case "event":
            handleEvent(message)
        default:
            break
        }
    }
}

private extension WatchConnectivityManager {
    func handleEvent(_ message: [String: Any]) {
        guard let event = message["event"] as? String else {
            return
        }
        
        switch event {
        case "dismissDrowsy":
            print("Dismiss received")
            onDismissDrowsy?()
            // TODO: Change state
        default:
            break
        }
    }
}
