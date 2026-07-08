//
//  DriveTypeView.swift
//  drivecompanion
//
//  Created by Stephanie Vania Suwardi Data on 06/07/26.
//

import SwiftUI
import Combine

private enum MascotMood {
    case normal
    case drowsy
    case microsleep
}

struct DriveView: View {
    @ObservedObject var viewModel: AIViewModel
    let state: DrowsinessState
    @ObservedObject var restStopViewModel: RestStopViewModel
    @ObservedObject var camera: CameraViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isRestStopListVisible = false
    @State private var isCameraCheckVisible = false
    @State private var displayedMood: MascotMood = .normal
    @State private var lingerTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            moodBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Button {
                            isCameraCheckVisible = true
                        } label: {
                            Image(systemName: "camera.viewfinder")
                                .font(.title3)
                                .foregroundStyle(Color.primary)
                                .frame(width: 44, height: 44)
                                .background(Color(.systemBackground))
                                .clipShape(Circle())
                                .glassEffect()
                        }
                        Button {
                            isRestStopListVisible = true
                        } label: {
                            Image(systemName: "map")
                                .font(.title3)
                                .foregroundStyle(Color.primary)
                                .frame(width: 44, height: 44)
                                .background(Color(.systemBackground))
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
                
                MascotView(mood: displayedMood, isSpeaking: viewModel.status == .speaking)
                
                Spacer()

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
                    .frame(height: 200)
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
                            .background(AppColor.appPrimary)
                            .clipShape(Capsule())
                            .glassEffect()
                    }
                    
                    Button {
                        viewModel.toggleMute()
                    } label: {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 54, height: 54)
                            .overlay(
                                Image(systemName: viewModel.isMuted ? "mic.slash.fill" : "mic.fill")
                                    .foregroundStyle(viewModel.isMuted ? Color.red : Color(red: 0, green: 136/255.0, blue: 1))
                                    .font(.title3)
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
            }
            
//        #if DEBUG
//            VStack {
//                Spacer()
//                
//                debugCameraPreview
//                
//                Spacer()
//            }
//        #endif
        }
        .sheet(isPresented: $isCameraCheckVisible) {
            CameraCalibrationView(camera: camera, mode: .recheck) {
                isCameraCheckVisible = false
            }
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
        .overlay(alignment: .topLeading) {
            DrowsinessStatusPill(state: state)
                .padding(.top, 25)
                .padding(.leading, 16)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: restStopViewModel.suggestedStop?.id)
        .animation(.easeInOut(duration: 0.35), value: displayedMood)
        .onChange(of: state, initial: true) { _, newState in
            lingerTask?.cancel()
            lingerTask = nil
            switch newState {
            case .drowsy:
                displayedMood = .drowsy
            case .microsleep:
                displayedMood = .microsleep
            case .alert, .noFace:
                guard displayedMood != .normal else { return }
                let delay: TimeInterval = displayedMood == .microsleep ? 5 : 3
                lingerTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(delay))
                    guard !Task.isCancelled else { return }
                    displayedMood = .normal
                }
            }
        }
        .onDisappear {
            lingerTask?.cancel()
        }
    }

    @ViewBuilder
    private var moodBackground: some View {
        switch displayedMood {
        case .normal:
            Color(.systemBackground)
        case .drowsy:
            RadialGradient(
                colors: [Color(red: 1, green: 0.98, blue: 0.93), Color(red: 0.98, green: 0.91, blue: 0.78)],
                center: .center,
                startRadius: 0,
                endRadius: 500
            )
        case .microsleep:
            RadialGradient(
                colors: [Color(red: 1, green: 0.96, blue: 0.96), Color(red: 0.97, green: 0.8, blue: 0.78)],
                center: .center,
                startRadius: 0,
                endRadius: 500
            )
        }
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

private struct MascotView: View {
    let mood: MascotMood
    let isSpeaking: Bool

    @State private var showTalkFrame = false
    @State private var isBreathing = false

    private let talkTimer = Timer.publish(every: 0.28, on: .main, in: .common).autoconnect()

    private var frames: (idle: String, talk: String) {
        switch mood {
        case .normal:
            ("happy1", "happy2")
        case .drowsy:
            ("careful1", "careful2")
        case .microsleep:
            ("marah1", "marah2")
        }
    }

    private var frame: String {
        (isSpeaking && showTalkFrame) ? frames.talk : frames.idle
    }

    var body: some View {
        VStack(spacing: 0) {
            Image(frame)
                .resizable()
                .scaledToFit()
                .frame(height: 200)
                .scaleEffect(isBreathing ? 1.03 : 1.0)

            Ellipse()
                .fill(Color(.systemGray5).opacity(0.7))
                .frame(width: 160, height: 40)
                .offset(y: -10)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
        .onReceive(talkTimer) { _ in
            showTalkFrame = isSpeaking ? !showTalkFrame : false
        }
    }
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

#Preview("Drowsy") {
    let monitor = DrowsinessMonitor()
    let restStop = RestStopViewModel()
    let vm = AIViewModel(drowsinessMonitor: monitor, restStopViewModel: restStop)
    vm.history = [
        ChatTurn(role: .model, text: "Hei, kamu mulai keliatan ngantuk nih. Mau aku carikan tempat istirahat terdekat?"),
        ChatTurn(role: .user, text: "Ah nanggung, tinggal 30 menit lagi sampai rumah.")
    ]
    vm.status = .listening
    return DriveView(viewModel: vm, state: .drowsy, restStopViewModel: restStop, camera: CameraViewModel(monitor: monitor))
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
