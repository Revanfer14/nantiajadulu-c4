//
//  RootView.swift
//  drivecompanion
//
//  Created by Michelle Nathania on 05/07/26.
//

import SwiftUI

struct RootView: View {
    @AppStorage("hasSeenOnboarding")
    private var hasSeenOnboarding: Bool = false
    
    @State private var isOnboardingVisible: Bool = true
    
    var body: some View {
        ZStack (alignment: .bottom) {
            HomeView()
            
            if !hasSeenOnboarding && isOnboardingVisible {
                Color.black
                    .opacity(0.25)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                GettingStartedView(
                    isVisible: $isOnboardingVisible,
                    hasSeenOnboarding: $hasSeenOnboarding)
                .ignoresSafeArea(edges: .bottom)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(1)
            }
        }
    }
}

#Preview {
    RootView()
}
