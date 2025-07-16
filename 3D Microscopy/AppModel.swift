

//
//  AppModel.swift
//  3D Microscopy
//
//  Created by Future Lab XR1 on 7/8/25.
//

import SwiftUI
import RealityKit
import ARKit

enum GestureMode: String, CaseIterable {
        case none, drag, rotate, scale, measure
}
@MainActor
class AppModel: ObservableObject {

    @Published var gestureMode: GestureMode = .none

    let immersiveSpaceID = "ImmersiveSpace"
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    @Published var immersiveSpaceState = ImmersiveSpaceState.closed
    @Published var modelURL: URL? = nil
    @Published var availableModels: [URL] = []
    
    //for on/off button
    @Published var isOn: Bool = true {
        didSet {
            myEntities.root.isEnabled = isOn
        }
    }
    
    //hand tracking code
    private var arKitSession = ARKitSession()
    private var handTrackingProvider = HandTrackingProvider()
    @Published var resultString: String = ""
    let myEntities = MyEntities()
    
    func runSession() async {
            try! await arKitSession.run([handTrackingProvider])
        }
        
        func processAnchorUpdates() async {
            for await update in handTrackingProvider.anchorUpdates {
                
                //if isOn is flase then skip the rest
                guard isOn else { continue }
                
                let handAnchor = update.anchor
                
                guard handAnchor.isTracked,
                      let joint = handAnchor.handSkeleton?.joint(.indexFingerTip),
                      joint.isTracked else {
                    continue
                }
                
                let originFromWrist = handAnchor.originFromAnchorTransform
                
                let wristFromIndex = joint.anchorFromJointTransform
                let originFromIndex = originFromWrist * wristFromIndex
                
                let fingerTipEntity = myEntities.fingerTips[handAnchor.chirality]
                fingerTipEntity?.setTransformMatrix(originFromIndex, relativeTo: nil)
                
                myEntities.update()
                resultString = myEntities.getResultString()
        }
    }
}

