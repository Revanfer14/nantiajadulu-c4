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

    @State private var showSplash: Bool = true

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

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(.easeInOut(duration: 0.4)) {
                showSplash = false
            }
        }
    }
}

#Preview {
    RootView()
}
