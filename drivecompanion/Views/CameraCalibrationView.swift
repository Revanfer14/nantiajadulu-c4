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
                            Text("Periksa Posisi Kamera")
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
                Text("Periksa Posisi Kamera")
                    .font(AppFont.screenTitle)
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
            }

            if mode == .recheck {
                Spacer()
            }
            
            CameraPreview(session: camera.session)
                .aspectRatio(3/4, contentMode: .fit)
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
            

            Text(isFaceDetected
                 ? "Mantap, wajah kamu udah terdeteksi! \nSiap mulai berkendara."
                 : "Wajah kamu belum terdeteksi. \nCoba dekatin HP atau naikin brightness.")
                .font(AppFont.body)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if mode == .initialSetup {
                VStack(alignment: .leading, spacing: 12) {
                    tipRow(icon: "camera.viewfinder", text: "Taruh HP di phoneholder biar kamera stabil selama nyetir")
                    tipRow(icon: "applewatch", text: "Buka aplikasi Jaga di Apple Watch buat dapet getaran kalau kamu ngantuk (opsional)")
                }
                .padding(16)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 20)
            }

            Spacer()
            
            if mode == .initialSetup {
                PrimaryButton("Lanjut Berkendara") {
                    onContinue()
                }
                .disabled(!isFaceDetected)
                .opacity(!isFaceDetected ? 0.4 : 1)
                .padding(.horizontal, 28)
                
                if !isFaceDetected {
                    Button("Lanjutkan tanpa deteksi") {
                        onContinue()
                    }
                    .font(.footnote)
                    .foregroundStyle(AppColor.textSecondary)
                }
            }
        }
    }
}

private func tipRow(icon: String, text: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
        Image(systemName: icon)
            .font(.footnote)
            .foregroundStyle(AppColor.appPrimary)
            .frame(width: 20)

        Text(text)
            .font(.footnote)
            .foregroundStyle(AppColor.textSecondary)
    }
}

#Preview {
    let monitor = DrowsinessMonitor()
    CameraCalibrationView(camera: CameraViewModel(monitor: monitor), onContinue: {})
}
