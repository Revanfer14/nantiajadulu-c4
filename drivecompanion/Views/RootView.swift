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

    @State private var showSplash: Bool = true

    var body: some View {
        ZStack {
            if hasSeenOnboarding {
                HomeView()
                    .transition(.opacity)
            } else {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        hasSeenOnboarding = true
                    }
                }
                .transition(.opacity)
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
