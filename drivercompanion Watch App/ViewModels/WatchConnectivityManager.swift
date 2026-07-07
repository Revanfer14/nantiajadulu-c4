//
//  WatchConnectivityManager.swift
//  drivercompanion Watch App
//
//  Created by Michelle Nathania on 05/07/26.
//

import Foundation
import WatchConnectivity
import Combine

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
