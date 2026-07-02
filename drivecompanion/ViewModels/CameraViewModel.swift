//
//  CameraViewModel.swift
//  drivecompanion
//
//  Created by Filbert Naldo Wijaya on 02/07/26.
//

import Foundation
import ARKit
import Combine

final class CameraViewModel: ObservableObject {
    private let faceTrackingService = FaceTrackingService()
    private let drowsinessDetector = DrowsinessDetector()

    var session: ARSession { faceTrackingService.session }

    @Published var currentEyeOpenness: Double = 0.3
    @Published var currentJawOpen: Double = 0
    @Published var currentPitch: Double = 0
    @Published var hasFace: Bool = false

    @Published var perclos: Double = 0
    @Published var closedDuration: TimeInterval = 0
    @Published var isMicrosleep: Bool = false
    @Published var drowsinessState: DrowsinessState = .alert

    init() {
        faceTrackingService.onFaceUpdate = { [weak self] eyeOpenness, jawOpen, pitch in
            self?.handleFaceUpdate(eyeOpenness: eyeOpenness, jawOpen: jawOpen, pitch: pitch)
        }
        faceTrackingService.onFaceLost = { [weak self] in
            self?.handleFaceLost()
        }
        faceTrackingService.start()
    }

    private func handleFaceUpdate(eyeOpenness: Double, jawOpen: Double, pitch: Double) {
        let snapshot = drowsinessDetector.update(eyeOpenness: eyeOpenness, jawOpen: jawOpen, pitch: pitch)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.currentEyeOpenness = eyeOpenness
            self.currentJawOpen = jawOpen
            self.currentPitch = pitch
            self.hasFace = true
            self.perclos = snapshot.perclos
            self.closedDuration = snapshot.closedDuration
            self.isMicrosleep = snapshot.isMicrosleep
            self.drowsinessState = snapshot.state
        }
    }

    private func handleFaceLost() {
        drowsinessDetector.reset()
        DispatchQueue.main.async { [weak self] in
            self?.hasFace = false
            self?.closedDuration = 0
            self?.drowsinessState = .noFace
        }
    }
}
