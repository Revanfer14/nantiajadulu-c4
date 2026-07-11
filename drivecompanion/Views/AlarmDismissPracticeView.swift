//
//  AlarmDismissPracticeView.swift
//  drivecompanion
//
//  Created by Filbert Naldo Wijaya on 11/07/26.
//

import SwiftUI

struct AlarmDismissPracticeView: View {
    private enum Phase {
        case instructions
        case alarmActive
        case success
    }
    
    @ObservedObject var camera: CameraViewModel
    var onFinish: (_ completed: Bool) -> Void
    
    @State private var phase: Phase = .instructions
    @State private var openSince: Date?
    @State private var ringProgress: Double = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                CameraPreview(session: camera.session)
                    .frame(width: 300, height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(borderColor, lineWidth: 2)
                    )
                    .padding(.horizontal, 20)
                    .overlay(alignment: .top) {
                        DrowsinessStatusPill(state: camera.drowsinessState)
                            .padding(.top, 15)
                    }
                
                content
                
                Spacer()
                
                if phase == .success {
                    VStack(spacing: 12) {
                        PrimaryButton("Sudah Paham") {
                            onFinish(phase == .success)
                        }
                        
                        Button("Coba Lagi") {
                            phase = .instructions
                            openSince = nil
                            ringProgress = 0
                        }
                        .font(AppFont.body)
                        .foregroundStyle(AppColor.appPrimary)
                    }
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 20)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Latihan Matiin Alarm")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(AppColor.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onFinish(phase == .success)
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .background(.white)
        .onChange(of: camera.drowsinessState) { _, newState in
            switch (phase, newState) {
            case (.instructions, .drowsy), (.instructions, .microsleep):
                phase = .alarmActive
                openSince = nil
                ringProgress = 0
            case (.alarmActive, .alert):
                phase = .success
            case (.alarmActive, .noFace):
                phase = .instructions
                openSince = nil
                ringProgress = 0
            default:
                break
            }
        }
        .onChange(of: camera.currentEyeOpenness) { _, newValue in
            guard phase == .alarmActive else { return }
            updateRingProgress(eyeOpenness: newValue)
        }
    }
    
    private var borderColor: Color {
        switch camera.drowsinessState {
        case .noFace: Color(.systemGray4)
        case .alert: phase == .success ? Color.green : Color(.systemGray4)
        case .drowsy, .microsleep: Color.red
        }
    }
    
    @ViewBuilder
    private var content: some View {
        switch phase {
        case .instructions:
            if !camera.hasFace {
                statusText("Wajah kamu belum terdeteksi!", "Posisikan HP di depan wajah atau \ncoba naikin brightness, ya!")
            } else {
                statusText("Yuk simulasiin alarm!", "Coba ngantuk atau merem selama 2 detik ya, biar alarmnya nyala beneran.")
            }
        case .alarmActive:
            alarmActiveContent
        case .success:
            statusText("Alarm berhasil dimatikan!", "")
            Divider()
                .padding(.horizontal, 32)
            VStack(alignment: .leading, spacing: 12) {
                TipRow(icon: "bell.slash", text: "Untuk mematikan alarm, melek penuh selama 2 detik atau lakukan flick di Apple Watch.")
                TipRow(icon: "exclamationmark.triangle", text: "Lakukan sambil fokus menyetir. Tidak perlu melihat HP untuk mematikan alarm.")
            }
            .padding(.horizontal, 10)
        }
    }
    
    private var alarmActiveContent: some View {
        VStack(spacing: 20) {
            statusText("Coba matikan alarm!", "Melek penuh selama 2 detik atau lakukan flick di Apple Watch untuk mematikan alarm.")
            
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 12)
                
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(Color(red: 0, green: 136/255.0, blue: 1),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: ringProgress)
                
                Text(String(format: "%.1f", ringProgress * AlertnessConfig.requiredDuration))
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.textSecondary)
            }
            .frame(width: 100, height: 100)
        }
    }
    
    private func statusText(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.center)
            
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private func updateRingProgress(eyeOpenness: Double) {
        if eyeOpenness >= AlertnessConfig.eyeOpenThreshold {
            let since = openSince ?? Date()
            if openSince == nil { openSince = since }
            ringProgress = min(Date().timeIntervalSince(since) / AlertnessConfig.requiredDuration, 1.0)
        } else {
            openSince = nil
            ringProgress = 0
        }
    }
}

#Preview {
    let monitor = DrowsinessMonitor()
    AlarmDismissPracticeView(camera: CameraViewModel(monitor: monitor), onFinish: { _ in })
}
