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
}
