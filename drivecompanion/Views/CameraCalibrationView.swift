//
//  CameraCalibrationView.swift
//  drivecompanion
//
//  Created by Filbert Naldo Wijaya on 08/07/26.
//

import SwiftUI

struct CameraCalibrationView: View {
    enum Mode {
        case initialSetup
        case recheck
    }

    @ObservedObject var camera: CameraViewModel
    var mode: Mode = .initialSetup
    var onContinue: () -> Void

    private var isFaceDetected: Bool {
        camera.hasFace
    }

    var body: some View {
        if mode == .recheck {
            NavigationStack {
                content
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("Set Up Kamera")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(AppColor.textPrimary)
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                onContinue()
                            } label: {
                                Image(systemName: "xmark")
                            }
                        }
                    }
            }
            .background(.white)
        } else {
            content
        }
    }

    private var content: some View {
        VStack(spacing: 20) {
            if mode == .initialSetup {
                Text("Set Up Kamera")
                    .font(AppFont.screenTitle)
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
            }

            if mode == .recheck {
                Spacer()
            }
            
            CameraPreview(session: camera.session)
                .frame(width: 300, height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(isFaceDetected ? Color.green : Color(.systemGray4), lineWidth: 2)
                )
                .padding(.horizontal, 20)
                .overlay(alignment: .top) {
                    DrowsinessStatusPill(state: camera.drowsinessState)
                        .padding(.top, 15)
                }
            
            VStack(spacing: 10) {
                Text(isFaceDetected
                     ? "Wajah kamu sudah terdeteksi!"
                     : "Wajah kamu belum terdeteksi!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.center)
                
                Text(isFaceDetected
                     ? "Kamu fokus menyetir saja, aku yang jaga dari sini. Hati-hati di jalan, ya!"
                     : "Posisikan HP di depan wajah atau \ncoba naikin brightness, ya!")
                .font(AppFont.body)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.top, mode == .initialSetup ? 0 : 20)

            if mode == .initialSetup {
                Divider()
                    .padding(.horizontal, 32)
            }
            
            if mode == .initialSetup {
                VStack(alignment: .leading, spacing: 12) {
                    tipRow(icon: "camera.viewfinder", text: "Letakkan HP di phoneholder agar kamera stabil selama nyetir")
                    tipRow(icon: "applewatch", text: "Buka aplikasi Jaga di Apple Watch untuk peringatan getar. (opsional)")
                    tipRow(icon: "bell.slash", text: "Buka mata 3 detik atau flick Apple Watch untuk mematikan alarm.")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            
            if mode == .recheck {
                Spacer()
            }
            
            if mode == .initialSetup {
                PrimaryButton("Lanjut Berkendara") {
                    onContinue()
                }
                .disabled(!isFaceDetected)
                .opacity(!isFaceDetected ? 0.4 : 1)
                .padding(.horizontal, 20)
            }
        }
    }
}

private func tipRow(icon: String, text: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
        Image(systemName: icon)
            .font(.body)
            .foregroundStyle(Color.black)
            .frame(width: 20)

        Text(text)
            .font(.body)
            .foregroundStyle(Color.black)
    }
}

#Preview {
    let monitor = DrowsinessMonitor()
    CameraCalibrationView(camera: CameraViewModel(monitor: monitor), onContinue: {})
}
