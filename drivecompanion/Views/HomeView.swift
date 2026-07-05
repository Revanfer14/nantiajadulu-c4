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
            // TODO: Add background cloud, car, mascot
            
            VStack (alignment: .leading, spacing: 8) {
                Text("Udah siap jalan hari ini? 🚗")
                    .foregroundStyle(AppColor.textPrimary)
                    .font(AppFont.screenTitle)
                
                Text("Tenang aja, aku bakal nemenin dan jagain kamu sepanjang jalan.")
                    .foregroundStyle(AppColor.textSecondary)
                    .font(AppFont.body)
                
                Spacer()
                
                PrimaryButton("Lanjutkan") {
                    isDrivingActive = true
                }
            }
            .padding(.top, 50)
            .padding(.horizontal, 20)
        }
        .fullScreenCover(isPresented: $isDrivingActive) {
            DrivingView()
        }
    }
}

#Preview {
    HomeView()
}
