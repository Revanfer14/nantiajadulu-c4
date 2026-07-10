//
//  Onboarding.swift
//  drivecompanion
//
//  Created by Stephanie Vania Suwardi Data on 03/07/26.
//

import SwiftUI
import Combine

private struct OnboardingSlide {
    let imageName: String
    let title: String
    let subtitle: String
}

struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var currentPage = 0
    @State private var hasSeenAllSlides = false

    private let slides: [OnboardingSlide] = [
        OnboardingSlide(imageName: "onboarding1", title: "Mengawasi Perjalanan Anda", subtitle: "Memantau kondisi Anda selama berkendara secara real-time."),
        OnboardingSlide(imageName: "onboarding2", title: "Memberikan Peringatan Dini", subtitle: "Memberi peringatan saat tanda-tanda kantuk mulai terdeteksi."),
        OnboardingSlide(imageName: "onboarding3", title: "Teman Bicara Selama Perjalanan", subtitle: "Mengajak Anda mengobrol agar tetap fokus dan terjaga selama perjalanan."),
        OnboardingSlide(imageName: "onboarding4", title: "Rekomendasi Area Istirahat", subtitle: "Menyarankan area istirahat terdekat saat Anda perlu beristirahat.")
    ]

    private let autoAdvanceTimer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color(red: 232 / 255, green: 244 / 255, blue: 251 / 255)
                .ignoresSafeArea()

            VStack(spacing: 3) {
                TabView(selection: $currentPage) {
                    ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                        Color.clear
                            .overlay {
                                Image(slide.imageName)
                                    .resizable()
                                    .scaledToFill()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .padding(.horizontal, 34)
                .padding(.vertical, 16)
                .frame(maxHeight: .infinity)

                VStack(alignment: .leading, spacing: 8) {
                    Text(slides[currentPage].title)
                        .font(.title2.bold())
                        .foregroundStyle(AppColor.textPrimary)

                    Text(slides[currentPage].subtitle)
                        .font(AppFont.body)
                        .foregroundStyle(AppColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 33)
                .frame(height: 96)

                PrimaryButton("Mulai") {
                    onFinish()
                }
                .disabled(!hasSeenAllSlides)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
        .onReceive(autoAdvanceTimer) { _ in
            withAnimation {
                currentPage = (currentPage + 1) % slides.count
            }
        }
        .onChange(of: currentPage) { _, newValue in
            if newValue == slides.count - 1 {
                hasSeenAllSlides = true
            }
        }
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
