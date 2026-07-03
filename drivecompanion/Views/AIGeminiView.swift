//
//  AIGeminiView.swift
//  drivecompanion
//
//  Created by Revan Ferdinand on 02/07/26.
//

import SwiftUI

@available(iOS 26.0, *)
struct AIGeminiView: View {
    @StateObject private var viewModel = AIViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Text(viewModel.status.rawValue)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .animation(.easeInOut, value: viewModel.status.rawValue)


                Spacer()

                Picker("Mode", selection: $viewModel.selectedMode) {
                    ForEach(SessionMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(viewModel.isRunning)

                Button {
                    Task {
                        if viewModel.isRunning {
                            viewModel.stop()
                        } else {
                            await viewModel.start()
                        }
                    }
                } label: {
                    Label(
                        viewModel.isRunning ? "Stop" : "Start",
                        systemImage: viewModel.isRunning ? "stop.circle.fill" : "mic.circle.fill"
                    )
                    .font(.title)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(viewModel.isRunning ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
                    .foregroundStyle(viewModel.isRunning ? .red : .green)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                if viewModel.permissionDenied {
                    Text("Jaga butuh izin mikrofon dan pengenalan suara. Buka Pengaturan → Privasi untuk mengaktifkannya.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .navigationTitle("C4")
            .toolbar {  
                ToolbarItem(placement: .topBarTrailing) {
                    Text("Model: \(viewModel.activeModel.isEmpty ? "-" : viewModel.activeModel)")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

#Preview {
    AIGeminiView()
}
