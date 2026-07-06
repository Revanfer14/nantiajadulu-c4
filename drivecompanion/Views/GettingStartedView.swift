//
//  GettingStartedView.swift
//  drivecompanion
//
//  Created by Michelle Nathania on 03/07/26.
//

import SwiftUI

struct GettingStartedView: View {
    
    @GestureState var dragOffset: CGFloat = 0
    @State private var hasPermission: Bool = false
    
    @Binding var isVisible: Bool
    @Binding var hasSeenOnboarding: Bool
    
    var body: some View {
        VStack (alignment: .leading, spacing: 20) {
            // MARK: Header
            Text("Kenalan dengan Jaga!")
                .font(AppFont.screenTitle)
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
                withAnimation(
                    .spring(response: 0.45,
                            dampingFraction: 0.85)
                ) {
                    isVisible = false
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    hasSeenOnboarding = true
                }
            }
        }
        .padding(.top, 50)
        .padding(.bottom, 30)
        .padding(.horizontal, 20)
        .background(AppColor.background)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .offset(y: min(dragOffset * 0.35, 120))
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    state = max(value.translation.height, 0) } // kalo negative, bisa drag ke atas jg
        )
    }
}

#Preview {
    GettingStartedView(isVisible: .constant(true), hasSeenOnboarding: .constant(false))
}
