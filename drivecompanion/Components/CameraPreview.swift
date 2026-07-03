//
//  CameraPreview.swift
//  drivecompanion
//
//  Created by Filbert Naldo Wijaya on 02/07/26.
//

import SwiftUI
import ARKit

struct CameraPreview: UIViewRepresentable {
    let session: ARSession
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.session = session
        view.delegate = context.coordinator
        view.automaticallyUpdatesLighting = true
        return view
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {}
    
    class Coordinator: NSObject, ARSCNViewDelegate {
        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            guard let device = renderer.device,
                  let faceGeometry = ARSCNFaceGeometry(device: device) else { return nil }
            
            faceGeometry.firstMaterial?.fillMode = .lines
            faceGeometry.firstMaterial?.diffuse.contents = UIColor.white
            
            return SCNNode(geometry: faceGeometry)
        }
        
        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let faceAnchor = anchor as? ARFaceAnchor,
                  let faceGeometry = node.geometry as? ARSCNFaceGeometry else { return }
            faceGeometry.update(from: faceAnchor.geometry)
        }
    }
}
