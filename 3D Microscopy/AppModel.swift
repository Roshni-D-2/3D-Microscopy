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
        case none, drag, rotate, scale, measure, crop
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
    @Published var isOn: Bool = false {
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
           do {
               if HandTrackingProvider.isSupported {
                   print(" tracking is supported")
                   try await arKitSession.run([handTrackingProvider])
                   print("and tracking session started successfully")
               } else {
                   print("and tracking is not supported on this device")
               }
           } catch {
               print("Failed  \(error)")
           }
       }
       
       func processAnchorUpdates() async {
           print("Starting to process anchor updates...")
           
           for await update in handTrackingProvider.anchorUpdates {
               let handAnchor = update.anchor
               let handType = handAnchor.chirality == .left ? "LEFT" : "RIGHT"
               
               if !handAnchor.isTracked {
//                   print("\(handType) hand not tracked")
                   continue
               }
               
               guard let handSkeleton = handAnchor.handSkeleton else {
//                   print("\(handType) hand skeleton not available")
                   continue
               }
               
               let joint = handSkeleton.joint(.indexFingerTip);
               
               guard joint.isTracked else {
//                   print("\(handType) index finger tip not tracked")
                   continue
               }
               
               let originFromWrist = handAnchor.originFromAnchorTransform
               let wristFromIndex = joint.anchorFromJointTransform
               let originFromIndex = originFromWrist * wristFromIndex
               
               let fingerTipEntity = myEntities.fingerTips[handAnchor.chirality]
               fingerTipEntity?.setTransformMatrix(originFromIndex, relativeTo: nil)
               
               // debug position
//               let position = fingerTipEntity?.position ?? SIMD3<Float>(0, 0, 0)
//               if isOn && (handAnchor.chirality == .left) { // Only log left hand to reduce spam
////                   print("\(handType) finger at: \(position)")
//               }
               
               // Only update visual elements if measuring is on
               if isOn {
                   myEntities.update()
                   resultString = myEntities.getResultString()
               }
           }
       }
   }
