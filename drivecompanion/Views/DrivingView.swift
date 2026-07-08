//
//  RootView.swift
//  drivecompanion
//
//  Created by Filbert Naldo Wijaya on 03/07/26.
//

import SwiftUI

//@available(iOS 26.0, *)
struct DrivingView: View {
    @StateObject private var drowsinessMonitor: DrowsinessMonitor
    @StateObject private var camera: CameraViewModel
    @StateObject private var viewModel: AIViewModel
    @StateObject private var restStopViewModel: RestStopViewModel
    
    @State private var isRestStopListVisible = false
    
    init() {
        let monitor = DrowsinessMonitor()
        let restStop = RestStopViewModel()
        _drowsinessMonitor = StateObject(wrappedValue: monitor)
        _camera = StateObject(wrappedValue: CameraViewModel(monitor: monitor))
        _restStopViewModel = StateObject(wrappedValue: restStop)
        _viewModel = StateObject(wrappedValue: AIViewModel(drowsinessMonitor: monitor, restStopViewModel: restStop))
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
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
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isRestStopListVisible = true
                        } label: {
                            Image(systemName: "mappin.and.ellipse")
                        }
                    }
                }
                .sheet(isPresented: $isRestStopListVisible) {
                    RestStopListView(restStopViewModel: restStopViewModel)
                }
            }
            
        #if DEBUG
            VStack {
                Spacer()
                
                debugCameraPreview
                
                Spacer()
            }
        #endif
        }
        .overlay(alignment: .top) {
            if let candidate = restStopViewModel.suggestedStop {
                RestStopCard(
                    candidate: candidate,
                    onAccept: {
                        if let confirmed = restStopViewModel.confirm() {
                            restStopViewModel.openInMaps(confirmed)
                        }
                    },
                    onDismiss: { restStopViewModel.dismiss() })
                .padding(.top, 80)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay(alignment: .topLeading) {
            DrowsinessStatusPill(state: drowsinessMonitor.state)
                .padding(.top, 8)
                .padding(.leading, 16)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: restStopViewModel.suggestedStop?.id)
    }
    
#if DEBUG
    private var debugCameraPreview: some View {
        CameraPreview(session: camera.session)
            .frame(width: 110, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.yellow.opacity(0.8), lineWidth: 1.5)
            )
            .overlay(alignment: .topLeading) {
                Text("DEBUG")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.yellow.opacity(0.85))
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(4)
            }
            .shadow(radius: 4)
            .padding(.trailing, 16)
            .padding(.bottom, 24)
            .allowsHitTesting(false)
    }
#endif
}

#Preview {
    DrivingView()
}
