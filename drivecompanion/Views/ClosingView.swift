//
//  ClosingView.swift
//  drivecompanion
//
//  Created by Revan Ferdinand on 09/07/26.
//

import SwiftUI

struct ClosingView: View {
    let outcome: DrowsinessState
    let onDone: () -> Void

    private var title: String {
        switch outcome {
        case .microsleep:
            return "Waktunya Istirahat Total"
        case .drowsy:
            return "Butuh Jeda Sebentar?"
        case .alert, .noFace:
            return "Perjalanan Aman!"
        }
    }

    private var message: String {
        switch outcome {
        case .microsleep:
            return "Kamu sempat tertidur tadi. Demi keselamatanmu, tolong istirahat total sebelum menyetir lagi ya."
        case .drowsy:
            return "Ada sedikit tanda lelah tadi. Yuk, istirahat sejenak biar kembali segar."
        case .alert, .noFace:
            return "Tidak ada tanda ngantuk sama sekali. Pertahankan fokusmu yang keren ini ya!"
        }
    }

    private var mascotImageName: String {
        switch outcome {
        case .microsleep:
            return "marah1"
        case .drowsy:
            return "careful1"
        case .alert, .noFace:
            return "happy1"
        }
    }

    var body: some View {
        ZStack {
            Image(.backgroundHome)
                .resizable()
                .scaleEffect(2)
                .scaledToFit()
                .padding(.top, 140)
                .ignoresSafeArea()

            Image(mascotImageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 220)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text(title)
                        .foregroundStyle(AppColor.textPrimary)
                        .font(AppFont.screenTitle)
                        .multilineTextAlignment(.center)

                    Text(message)
                        .foregroundStyle(AppColor.textSecondary)
                        .font(AppFont.body)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .padding(.top, 30)

                Spacer()

                PrimaryButton("Kembali") {
                    onDone()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
    }
}

#Preview("Safe") {
    ClosingView(outcome: .alert, onDone: {})
}

#Preview("Drowsy") {
    ClosingView(outcome: .drowsy, onDone: {})
}

#Preview("Microsleep") {
    ClosingView(outcome: .microsleep, onDone: {})
}
