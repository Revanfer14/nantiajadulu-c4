//
//  DriveTypeView.swift
//  drivecompanion
//
//  Created by Stephanie Vania Suwardi Data on 06/07/26.
//

import SwiftUI

struct DriveView: View {
    @ObservedObject var viewModel: AIViewModel
    let state: DrowsinessState
    @ObservedObject var restStopViewModel: RestStopViewModel
    @ObservedObject var camera: CameraViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isRestStopListVisible = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if state == .microsleep {
                Color.red.ignoresSafeArea()
            } else {
                Color(.systemBackground).ignoresSafeArea()
            }

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Image(systemName: "camera.viewfinder")
                            .font(.title3)
                            .foregroundStyle(Color(red: 52/255.0, green: 199/255.0, blue: 89/255.0))
                            .frame(width: 44, height: 44)
                            .background(Color(.systemBackground).opacity(state == .microsleep ? 0.15 : 1))
                            .clipShape(Circle())
                            .glassEffect()

                        Button {
                            isRestStopListVisible = true
                        } label: {
                            Image(systemName: "map")
                                .font(.title3)
                                .foregroundStyle(state == .microsleep ? Color.white : Color.primary)
                                .frame(width: 44, height: 44)
                                .background(Color(.systemBackground).opacity(state == .microsleep ? 0.15 : 1))
                                .clipShape(Circle())
                                .glassEffect()
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)                    
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()

                VStack(spacing: 0) {
                    Image(systemName: "figure.wave")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 160)
                        .foregroundStyle(AppColor.appPrimary)

                    Ellipse()
                        .fill(Color(.systemGray5).opacity(0.7))
                        .frame(width: 160, height: 40)
                        .offset(y: -10)
                }

                Spacer()

                Picker("Mode", selection: $viewModel.selectedMode) {
                    ForEach(SessionMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(viewModel.history.indices, id: \.self) { index in
                                ChatBubble(turn: viewModel.history[index])
                                    .id(index)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                    }
                    .frame(height: 260)
                    .onChange(of: viewModel.history.count) {
                        if viewModel.history.count > 0 {
                            withAnimation {
                                proxy.scrollTo(viewModel.history.count - 1, anchor: .bottom)
                            }
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        viewModel.stop()
                        dismiss()
                    } label: {
                        Text("Berhenti Mengemudi")
                            .font(.headline)
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(state == .microsleep ? Color.black : AppColor.appPrimary)
                            .clipShape(Capsule())
                            .glassEffect()
                    }

                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 54, height: 54)
                        .overlay(
                            Image(systemName: viewModel.status == .listening ? "mic.fill" : "mic")
                                .foregroundStyle(Color(red: 0, green: 136/255.0, blue: 1))
                                .font(.title3)
                        )
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
                .background(state == .microsleep ? Color.red : Color.clear)
            }

        #if DEBUG
            VStack {
                Spacer()

                debugCameraPreview

                Spacer()
            }
        #endif
        }
        .sheet(isPresented: $isRestStopListVisible) {
            RestStopListView(restStopViewModel: restStopViewModel)
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

#Preview("Normal") {
    let monitor = DrowsinessMonitor()
    let restStop = RestStopViewModel()
    let vm = AIViewModel(drowsinessMonitor: monitor, restStopViewModel: restStop)
    vm.history = [
        ChatTurn(role: .model, text: "Eh, macetnya lumayan tadi. Lu udah di jalan dari jam berapa?"),
        ChatTurn(role: .user, text: "Dari jam 7 pagi, baru nyampe sekarang. Capek banget."),
        ChatTurn(role: .model, text: "Lumayan lama tuh. Udah makan belum? Jangan sampai laper pas nyetir.")
    ]
    vm.status = .listening
    return DriveView(viewModel: vm, state: .alert, restStopViewModel: restStop, camera: CameraViewModel(monitor: monitor))
}

#Preview("Microsleep") {
    let monitor = DrowsinessMonitor()
    let restStop = RestStopViewModel()
    let vm = AIViewModel(drowsinessMonitor: monitor, restStopViewModel: restStop)
    vm.history = [
        ChatTurn(role: .model, text: "Hei, tadi kamu sempet microsleep. Itu bahaya banget, mending cari tempat istirahat sekarang."),
        ChatTurn(role: .user, text: "Iya, gua juga kaget. Untung masih aman.")
    ]
    vm.status = .listening
    return DriveView(viewModel: vm, state: .microsleep, restStopViewModel: restStop, camera: CameraViewModel(monitor: monitor))
}
