//
//  HomeView.swift
//  drivecompanion
//
//  Created by Michelle Nathania on 05/07/26.
//

import SwiftUI

struct HomeView: View {
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
                    // TODO: Navigate to DrivingView
                }
            }
            .padding(.top, 50)
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    HomeView()
}
