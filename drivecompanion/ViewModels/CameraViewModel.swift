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
    private let alarmService = AlarmService()
    private let drowsinessMonitor: DrowsinessMonitor

    var session: ARSession { faceTrackingService.session }

    @Published var currentEyeOpenness: Double = 0.3
    @Published var currentJawOpen: Double = 0
    @Published var currentPitch: Double = 0
    @Published var hasFace: Bool = false

    @Published var perclos: Double = 0
    @Published var closedDuration: TimeInterval = 0
    @Published var isMicrosleep: Bool = false
    @Published var drowsinessState: DrowsinessState = .alert
    
    private var previousSentState: DrowsinessState?

    init(monitor: DrowsinessMonitor) {
        self.drowsinessMonitor = monitor
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
            self.updateAlarm(for: snapshot.state)
            self.drowsinessMonitor.update(state: snapshot.state, perclos: snapshot.perclos, closedDuration: snapshot.closedDuration)
            
            // Send state only if it's different than the previous one
            if self.previousSentState != snapshot.state {
                WatchConnectivityManager.shared.sendDrowsinessState(snapshot.state)
                self.previousSentState = snapshot.state
            }
        }
    }

    private func handleFaceLost() {
        drowsinessDetector.reset()
        alarmService.stop()
        DispatchQueue.main.async { [weak self] in
            self?.hasFace = false
            self?.closedDuration = 0
            self?.drowsinessState = .noFace
            self?.drowsinessMonitor.update(state: .noFace, perclos: 0, closedDuration: 0)
            
            WatchConnectivityManager.shared.sendDrowsinessState(.noFace)
            self?.previousSentState = .noFace
        }
    }
    
    private func updateAlarm(for state: DrowsinessState) {
        switch state {
        case .microsleep:
            alarmService.play("microsleep_alert")
        case .drowsy:
            alarmService.play("drowsy_alert")
        case .alert, .noFace:
            alarmService.stop()
        }
    }
}
