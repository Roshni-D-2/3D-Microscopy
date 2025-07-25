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
    
    // MARK: - Pinch Detection Properties
    private var leftPinchDistance: Float = 0
    private var rightPinchDistance: Float = 0
    private var leftWasPinched: Bool = false
    private var rightWasPinched: Bool = false
    private let pinchThreshold: Float = 0.025 // 2.5cm threshold for pinch detection
    private var lastPinchTime: Date = Date()
    private let pinchCooldown: TimeInterval = 0.5 // Half second cooldown between pinches
    
    func runSession() async {
        do {
            if HandTrackingProvider.isSupported {
                print("Hand tracking is supported")
                try await arKitSession.run([handTrackingProvider])
                print("Hand tracking session started successfully")
            } else {
                print("Hand tracking is not supported on this device")
            }
        } catch {
            print("Failed to start hand tracking: \(error)")
        }
    }
    
    func processAnchorUpdates() async {
        print("Starting to process anchor updates...")
        
        for await update in handTrackingProvider.anchorUpdates {
            let handAnchor = update.anchor
            let handType = handAnchor.chirality == .left ? "LEFT" : "RIGHT"
            
            if !handAnchor.isTracked {
                continue
            }
            
            guard let handSkeleton = handAnchor.handSkeleton else {
                continue
            }
            
            // Get both index finger tip and thumb tip for pinch detection
            let indexJoint = handSkeleton.joint(.indexFingerTip)
            let thumbJoint = handSkeleton.joint(.thumbTip)
            
            guard indexJoint.isTracked else {
                continue
            }
            
            let originFromWrist = handAnchor.originFromAnchorTransform
            let wristFromIndex = indexJoint.anchorFromJointTransform
            let originFromIndex = originFromWrist * wristFromIndex
            
            // Update fingertip entity position (existing functionality)
            let fingerTipEntity = myEntities.fingerTips[handAnchor.chirality]
            fingerTipEntity?.setTransformMatrix(originFromIndex, relativeTo: nil)
            
            // MARK: - Pinch Detection (NEW)
            if thumbJoint.isTracked && gestureMode == .measure && isOn {
                let wristFromThumb = thumbJoint.anchorFromJointTransform
                let originFromThumb = originFromWrist * wristFromThumb
                
                // Calculate positions
                let indexPos = SIMD3<Float>(originFromIndex.columns.3.x,
                                          originFromIndex.columns.3.y,
                                          originFromIndex.columns.3.z)
                let thumbPos = SIMD3<Float>(originFromThumb.columns.3.x,
                                          originFromThumb.columns.3.y,
                                          originFromThumb.columns.3.z)
                
                let pinchDistance = distance(indexPos, thumbPos)
                
                // Detect pinch gestures
                detectPinchGesture(handAnchor.chirality, pinchDistance)
            }
            
            // Only update visual elements if measuring is on (existing functionality)
            if isOn {
                myEntities.update()
                resultString = myEntities.getResultString()
            }
        }
    }
    
    // MARK: - Pinch Detection Methods (NEW)
    
    private func detectPinchGesture(_ chirality: HandAnchor.Chirality, _ currentDistance: Float) {
        let now = Date()
        
        // Check cooldown to prevent rapid-fire pinches
        guard now.timeIntervalSince(lastPinchTime) > pinchCooldown else { return }
        
        switch chirality {
        case .left:
            let wasPinched = leftWasPinched
            let isPinched = currentDistance < pinchThreshold
            
            if !wasPinched && isPinched {
                // Left hand just pinched - place measurement
                handleLeftPinch()
                lastPinchTime = now
            }
            leftWasPinched = isPinched
            leftPinchDistance = currentDistance
            
        case .right:
            let wasPinched = rightWasPinched
            let isPinched = currentDistance < pinchThreshold
            
            if !wasPinched && isPinched {
                // Right hand just pinched - remove last measurement
                handleRightPinch()
                lastPinchTime = now
            }
            rightWasPinched = isPinched
            rightPinchDistance = currentDistance
        }
    }
    
    private func handleLeftPinch() {
        // Left hand pinch = Place measurement
        myEntities.placeMeasurement()
        print("Measurement placed via left hand pinch")
        
        // Optional: Add haptic feedback if available
        // AudioServicesPlaySystemSound(1519) // Light haptic
    }
    
    private func handleRightPinch() {
        // Right hand pinch = Remove last measurement
        myEntities.removeLastMeasurement()
        print("Last measurement removed via right hand pinch")
        
        // Optional: Add haptic feedback if available
        // AudioServicesPlaySystemSound(1520) // Medium haptic
    }
    
    // MARK: - Public Methods for UI Controls (NEW)
    
    func placeMeasurement() {
        myEntities.placeMeasurement()
    }
    
    func removeLastMeasurement() {
        myEntities.removeLastMeasurement()
    }
    
    func clearAllMeasurements() {
        myEntities.clearAllMeasurements()
        print("🧹 All measurements cleared")
    }
    
    // MARK: - Debug Methods (NEW)
    
    func getPinchStatus() -> String {
        let leftStatus = leftWasPinched ? "PINCHED" : String(format: "%.1fcm", leftPinchDistance * 100)
        let rightStatus = rightWasPinched ? "PINCHED" : String(format: "%.1fcm", rightPinchDistance * 100)
        return "L: \(leftStatus) | R: \(rightStatus)"
    }
}
