//
//  FaceTrackingService.swift
//  drivecompanion
//
//  Created by Filbert Naldo Wijaya on 02/07/26.
//

import ARKit
import SceneKit

final class FaceTrackingService: NSObject {
    let session = ARSession()

    var onFaceUpdate: ((_ eyeOpenness: Double, _ jawOpen: Double, _ pitch: Double) -> Void)?
    var onFaceLost: (() -> Void)?

    override init() {
        super.init()
        session.delegate = self
    }

    func start() {
        guard ARFaceTrackingConfiguration.isSupported else {
            print("ARKit face tracking is not supported")
            return
        }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        session.run(configuration)
    }

    // get the face landmarks data from AR
    private func processFaceAnchor(_ faceAnchor: ARFaceAnchor) {
        let blendShapes = faceAnchor.blendShapes

        let blinkLeft = blendShapes[.eyeBlinkLeft]?.doubleValue ?? 0
        let blinkRight = blendShapes[.eyeBlinkRight]?.doubleValue ?? 0
        let eyeOpenness = 1 - (blinkLeft + blinkRight) / 2
        let jawOpen = blendShapes[.jawOpen]?.doubleValue ?? 0

        let node = SCNNode()
        node.simdTransform = faceAnchor.transform
        let pitch = Double(node.simdEulerAngles.x)

        onFaceUpdate?(eyeOpenness, jawOpen, pitch)
    }
}

// run AR session every frame to detect face landmarks
extension FaceTrackingService: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let faceAnchor = anchors.compactMap({ $0 as? ARFaceAnchor }).first else { return }
        processFaceAnchor(faceAnchor)
    }

    // fallback if tracking lost
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        guard anchors.contains(where: { $0 is ARFaceAnchor }) else { return }
        onFaceLost?()
    }
}
