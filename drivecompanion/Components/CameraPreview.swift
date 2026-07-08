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
        private weak var faceNode: SCNNode?
        
        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            guard let device = renderer.device,
                  let faceGeometry = ARSCNFaceGeometry(device: device) else { return nil }
            
            faceGeometry.firstMaterial?.fillMode = .lines
            faceGeometry.firstMaterial?.diffuse.contents = UIColor.white
            
            let node = SCNNode(geometry: faceGeometry)
            faceNode = node
            return node
        }
        
        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            guard let sceneView = renderer as? ARSCNView,
                  let frame = sceneView.session.currentFrame,
                  let faceAnchor = frame.anchors.compactMap({ $0 as? ARFaceAnchor }).first else { return }
            
            if let node = faceNode, let faceGeometry = node.geometry as? ARSCNFaceGeometry {
                faceGeometry.update(from: faceAnchor.geometry)
                node.simdTransform = faceAnchor.transform
            } else if let node = self.renderer(sceneView, nodeFor: faceAnchor) {
                node.simdTransform = faceAnchor.transform
                sceneView.scene.rootNode.addChildNode(node)
            }
        }
    }
}
