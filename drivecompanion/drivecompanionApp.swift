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
            NavigationStack {
                Group {
                    switch selectedTab {
                    case .gemini:
                        AIGeminiView()
                    case .detection:
                        DetectionView()
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button(action: { selectedTab = .gemini }) {
                            VStack {
                                Image(systemName: "sparkles")
                                Text("AI Gemini")
                            }
                        }
                        .foregroundColor(selectedTab == .gemini ? .blue : .gray)

                        Spacer()

                        Button(action: { selectedTab = .detection }) {
                            VStack {
                                Image(systemName: "eye")
                                Text("Detection")
                            }
                        }
                        .foregroundColor(selectedTab == .detection ? .blue : .gray)
                    }
                }
            }
        }
    }
}
