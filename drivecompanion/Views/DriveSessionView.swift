//
//  DriveSessionView.swift
//  drivecompanion
//
//  Created by Revan Ferdinand on 08/07/26.
//

import SwiftUI

struct DriveSessionView: View {
    @StateObject private var drowsinessMonitor: DrowsinessMonitor
    @StateObject private var camera: CameraViewModel
    @StateObject private var viewModel: AIViewModel
    @StateObject private var restStopViewModel: RestStopViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var isCalibrated = false
    @State private var drowsyCount = 0
    @State private var microsleepCount = 0
    @State private var sessionOutcome: DrowsinessState?

    private var outcome: DrowsinessState {
        if microsleepCount >= 1 {
            return .microsleep
        } else if drowsyCount > 3 {
            return .drowsy
        } else {
            return .alert
        }
    }

    init() {
        let monitor = DrowsinessMonitor()
        let restStop = RestStopViewModel()
        _drowsinessMonitor = StateObject(wrappedValue: monitor)
        _camera = StateObject(wrappedValue: CameraViewModel(monitor: monitor))
        _restStopViewModel = StateObject(wrappedValue: restStop)
        _viewModel = StateObject(wrappedValue: AIViewModel(drowsinessMonitor: monitor, restStopViewModel: restStop))
    }

    var body: some View {
        if let sessionOutcome {
            ClosingView(outcome: sessionOutcome) {
                dismiss()
            }
        } else if isCalibrated {
            DriveView(viewModel: viewModel, state: drowsinessMonitor.state, restStopViewModel: restStopViewModel, camera: camera) {
                viewModel.stop()
                sessionOutcome = outcome
            }
            .task {
                await viewModel.start()
            }
            .onChange(of: drowsinessMonitor.state) { old, new in
                guard new != old else { return }
                switch new {
                case .drowsy:
                    drowsyCount += 1
                case .microsleep:
                    microsleepCount += 1
                case .alert, .noFace:
                    break
                }
            }
        } else {
            CameraCalibrationView(camera: camera) {
                isCalibrated = true
            }
        }
    }
}
