//
//  drivecompanionApp.swift
//  drivecompanion
//
//  Created by Revan Ferdinand on 01/07/26.
//

import SwiftUI

@main
struct drivecompanionApp: App {
   @State private var selectedTab: Tab = .gemini
    
    enum Tab {
        case gemini
        case detection
    }
    
    var body: some Scene {
        WindowGroup {
            if #available(iOS 26.0, *) {
                RootView()
            } else {
                Text("Jaga membutuhkan iOS 26 atau lebih baru.")
            }
        }
    }
}
