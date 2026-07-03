//
//  DetectionView.swift
//  drivecompanion
//
//  Created by Filbert Naldo Wijaya on 02/07/26.
//

import SwiftUI

struct DetectionView: View {
    @StateObject private var camera = CameraViewModel()
    
    private var stateLabel: (text: String, color: Color) {
        switch camera.drowsinessState {
        case .alert:
            return ("Alert", .green)
        case .drowsy:
            return ("Drowsy", .orange)
        case .microsleep:
            return ("Microsleep", .red)
        case .noFace:
            return ("No face detected", .gray)
        }
    }
    
    var body: some View {
        ZStack {
            CameraPreview(session: camera.session)
                .ignoresSafeArea()
            
            if camera.hasFace {
                VStack {
                    Text(String(format: "Openness: %.3f Jaw: %.3f Pitch: %.1f° PERCLOS: %.0f%% Closed: %.1fs%@",
                                camera.currentEyeOpenness,
                                camera.currentJawOpen,
                                camera.currentPitch * 180 / .pi,
                                camera.perclos * 100,
                                camera.closedDuration,
                                camera.isMicrosleep ? " ⚠️" : ""))
                    .font(.system(.title2, design: .monospaced))
                    .padding(8)
                    .background(Color.black.opacity(0.6))
                    .foregroundStyle(Color.white)
                    .cornerRadius(8)
                    Spacer()
                }
                .padding(.top, 60)
            }
            
            VStack {
                Text(stateLabel.text)
                    .font(.largeTitle)
                    .padding(8)
                    .background(stateLabel.color.opacity(0.8))
                    .foregroundStyle(Color.white)
                    .cornerRadius(8)
                Spacer()
            }
            .padding(.top, 180)
        }
    }
}

#Preview {
    DetectionView()
}
