//
//  HomeView.swift
//  drivecompanion
//
//  Created by Michelle Nathania on 05/07/26.
//

import SwiftUI

struct HomeView: View {
    @State private var isDrivingActive = false
    
    var body: some View {
        ZStack {
            Image(.backgroundHome)
                .resizable()
                .scaleEffect(2)
                .scaledToFit()
                .padding(.top, 140)
                .ignoresSafeArea()
            Image(.happy2)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 220)
                .ignoresSafeArea()
            
            VStack (alignment: .leading, spacing: 8) {
                Text("Udah siap jalan hari ini? 🚗")
                    .foregroundStyle(AppColor.textPrimary)
                    .font(AppFont.screenTitle)
                
                Text("Tenang aja, aku bakal nemenin dan jagain kamu sepanjang jalan.")
                    .foregroundStyle(AppColor.textSecondary)
                    .font(AppFont.body)
                
                Spacer()
                
                PrimaryButton("Mulai Berkendara") {
                    isDrivingActive = true
                }
            }
            .padding(.top, 30)
            .padding(.horizontal, 20)
        }
        .fullScreenCover(isPresented: $isDrivingActive) {
            DriveSessionView()
        }
    }
}

#Preview {
    HomeView()
}
