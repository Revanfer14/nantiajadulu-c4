//
//  SplashView.swift
//  drivecompanion
//
//  Created by Revan Ferdinand on 09/07/26.
//

import SwiftUI

struct SplashView: View {
    @State private var mascotOffsetY: CGFloat = -500
    @State private var mascotScale: CGFloat = 0.9
    @State private var textOpacity: Double = 0
    @State private var textOffsetY: CGFloat = 20
    @State private var textBlur: CGFloat = 6
    @State private var textScale: CGFloat = 0.8

    var body: some View {
        ZStack {
            Color(red: 0xE8 / 255, green: 0xF4 / 255, blue: 0xFB / 255)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image("happy1")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 400)
                    .offset(y: mascotOffsetY)
                    .scaleEffect(mascotScale)

                VStack(spacing: 10) {
                    Text("Jaga")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(Color("AppPrimary"))

                    Text("Teman setia di setiap perjalanan 🚗")
                        .font(.system(size: 20, weight: .medium))
                        .italic()
                        .foregroundStyle(Color("TextSecondary"))
                }
                .opacity(textOpacity)
                .offset(y: textOffsetY)
                .scaleEffect(textScale)
                .blur(radius: textBlur)
            }
        }
        .onAppear {
            withAnimation(.interpolatingSpring(stiffness: 170, damping: 9)) {
                mascotOffsetY = 0
                mascotScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.45)) {
                textOpacity = 1
                textOffsetY = 0
                textBlur = 0
                textScale = 1.0
            }
        }
    }
}

#Preview {
    SplashView()
}
