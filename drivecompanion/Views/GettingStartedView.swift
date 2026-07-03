//
//  GettingStartedView.swift
//  drivecompanion
//
//  Created by Michelle Nathania on 03/07/26.
//

import SwiftUI

struct GettingStartedView: View {
    private let permissionManager = PermissionManager()
    
    @State private var hasPermission: Bool = false
    
    @AppStorage("hasSeenOnboarding")
    private var hasSeenOnboarding: Bool = false
    
    var body: some View {
        VStack (alignment: .leading, spacing: 20) {
            Spacer()
            
            // MARK: Header
            Text("Kenalan dengan AppName!")
                .font(AppFont.screenTitle)
                .fontWeight(.bold)
                .foregroundStyle(AppColor.textPrimary)
            
            // MARK: Cards
            VStack (alignment: .leading, spacing: 16) {
                CardTransparent("Kamera Deteksi Kantuk", iconName: "camera.circle", description: "Mendeteksi tanda-tanda awal kantuk dengan presisi sebelum menjadi berbahaya.")
                
                CardTransparent("Apple Watch Peringatan Cepat", iconName: "apple.haptics.and.exclamationmark.triangle", description: "Memberikan peringatan dan getaran untuk membantu Anda kembali fokus tanpa mengalihkan pandangan dari jalan.")
                
                CardTransparent("Companion AI Interaktif", iconName: "person.wave.2", description: "Menemani perjalanan Anda dengan percakapan dan interaksi yang membantu Anda tetap fokus selama berkendara.")
                
                CardTransparent("Rekomendasi Area Istirahat", iconName: "iphone.gen3.badge.location", description: "Menyarankan lokasi istirahat terdekat berdasarkan lokasi Anda.")
            }
            
            Spacer()
            
            // MARK: Button
            PrimaryButton("Lanjutkan") {
                guard !hasPermission else {
                    return
                }
                
                hasPermission = true
                
                Task {
                    await permissionManager.requestPermissions()
                    hasSeenOnboarding = true
                }
            }
        }
        .padding(20)
    }
}

#Preview {
    GettingStartedView()
}
