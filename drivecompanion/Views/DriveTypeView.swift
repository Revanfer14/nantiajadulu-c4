//
//  DriveTypeView.swift
//  drivecompanion
//
//  Created by Stephanie Vania Suwardi Data on 06/07/26.
//

import SwiftUI

struct DrivingTypeView: View {
    // 1. Tambahkan viewModel di sini sebagai @ObservedObject
    @ObservedObject var viewModel: AIViewModel
    let state: DrowsinessState
    
    // 2. Ambil teks respons terakhir dari LLM Gemini di dalam history
    private var lastLLMResponse: String {
        viewModel.history.last(where: { $0.role == .model })?.text ?? "Menemanimu di perjalanan..."
    }
    
    var body: some View {
        Group {
            switch state {
            case .alert:
                // 3. Oper lastLLMResponse ke subview yang membutuhkan teks
                AlertStateView(message: lastLLMResponse)
            case .drowsy:
                DrowsyStateView(message: lastLLMResponse)
            case .microsleep:
                MicrosleepStateView(message: lastLLMResponse)
            case .noFace:
                NoFaceStateView()
            }
        }
        .animation(.easeInOut, value: state) 
    }
}

// MARK: - Subviews

struct AlertStateView: View {
    let message: String // Menerima teks dinamis
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct DrowsyStateView: View {
    let message: String // Menerima teks dinamis
    
    var body: some View {
        VStack(spacing: 10) {
            Text("Mengantuk terdeteksi! 🥱")
                .font(.headline)
                .foregroundColor(.orange)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.yellow.opacity(0.2))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct MicrosleepStateView: View {
    let message: String // Menerima teks dinamis
    
    var body: some View {
        VStack(spacing: 20) {
            Text("BAHAYA: MICROSLEEP! 🚨")
                .font(.largeTitle)
                .bold()
                .foregroundColor(.white)
            
            Text(message)
                .font(.title3)
                .bold()
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.red)
        .edgesIgnoringSafeArea(.all)
    }
}

struct NoFaceStateView: View {
    var body: some View {
        Text("Wajah tidak terdeteksi 🔍")
            .foregroundColor(.gray)
            .font(.subheadline)
    }
}

// MARK: - Preview Fix
#Preview {
    // Karena kita butuh AIViewModel di parameter, kita buat mock-nya di preview
    DrivingTypeView(
        viewModel: AIViewModel(drowsinessMonitor: DrowsinessMonitor()),
        state: .alert
    )
}
