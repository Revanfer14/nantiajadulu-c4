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
    
    @State private var isCalibrated = false
    
    init() {
        let monitor = DrowsinessMonitor()
        let restStop = RestStopViewModel()
        _drowsinessMonitor = StateObject(wrappedValue: monitor)
        _camera = StateObject(wrappedValue: CameraViewModel(monitor: monitor))
        _restStopViewModel = StateObject(wrappedValue: restStop)
        _viewModel = StateObject(wrappedValue: AIViewModel(drowsinessMonitor: monitor, restStopViewModel: restStop))
    }
    
    var body: some View {
        if isCalibrated {
            DriveView(viewModel: viewModel, state: drowsinessMonitor.state, restStopViewModel: restStopViewModel, camera: camera)
                .task {
                    await viewModel.start()
                }
        } else {
            CameraCalibrationView(camera: camera) {
                isCalibrated = true
            }
        }
    }
}
