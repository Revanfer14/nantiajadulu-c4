//
//  RootView.swift
//  drivecompanion
//
//  Created by Filbert Naldo Wijaya on 03/07/26.
//

import SwiftUI

@available(iOS 26.0, *)
struct RootView: View {
    @StateObject private var drowsinessMonitor: DrowsinessMonitor
    @StateObject private var camera: CameraViewModel

    init() {
        let monitor = DrowsinessMonitor()
        _drowsinessMonitor = StateObject(wrappedValue: monitor)
        _camera = StateObject(wrappedValue: CameraViewModel(monitor: monitor))
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AIGeminiView(drowsinessMonitor: drowsinessMonitor)
            
        #if DEBUG
            debugCameraPreview
        #endif
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

#Preview {
    RootView()
}
