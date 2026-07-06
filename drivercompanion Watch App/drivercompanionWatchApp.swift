//
//  drivercompanionApp.swift
//  drivercompanion Watch App
//
//  Created by Michelle Nathania on 05/07/26.
//

import SwiftUI

@main
struct drivercompanionWatchApp: App {
    private let watchConnectivityManager = WatchConnectivityManager.shared
    
    var body: some Scene {
        WindowGroup {
            DrivingView()
        }
    }
}
