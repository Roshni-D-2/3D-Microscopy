//
//  MyEntities.swift
//  3D Microscopy
//
//  Created by FutureLab XR2 on 7/9/25.
//
import SwiftUI
import RealityKit
import ARKit

@MainActor
class MyEntities {
    let root = Entity()
    let fingerTips: [HandAnchor.Chirality: Entity]
    let line = Entity()
    var resultBoard: Entity?
    
    init() {
        // Create more visible finger tip indicators
        let leftTip = ModelEntity(
            mesh: .generateSphere(radius: 0.008),
            materials: [SimpleMaterial(color: .red, roughness: 0.3, isMetallic: false)]
        )
        let rightTip = ModelEntity(
            mesh: .generateSphere(radius: 0.008),
            materials: [SimpleMaterial(color: .blue, roughness: 0.3, isMetallic: false)]
        )
        
        // Position them off-screen initially so they don't appear at origin
        leftTip.position = SIMD3<Float>(-1000, -1000, -1000)
        rightTip.position = SIMD3<Float>(-1000, -1000, -1000)
        
        fingerTips = [
            .left: leftTip,
            .right: rightTip
        ]
        
        fingerTips.values.forEach { root.addChild($0) }
        
        // Make the line more visible but initially hidden
        line.components.set(OpacityComponent(opacity: 0.9))
        line.isEnabled = false
        root.addChild(line)
        
        // Initially hide the root
        root.isEnabled = false
    }
    
    func add(_ resultBoardEntity: Entity) {
        resultBoard = resultBoardEntity
        root.addChild(resultBoardEntity)
    }
    
    func update() {
        guard let leftTip = fingerTips[.left],
              let rightTip = fingerTips[.right] else { return }
        
        // Check if both hands are actually tracked (not at initial position)
        let leftPos = leftTip.position
        let rightPos = rightTip.position
        
        let isLeftTracked = leftPos.x > -999 && leftPos.y > -999 && leftPos.z > -999
        let isRightTracked = rightPos.x > -999 && rightPos.y > -999 && rightPos.z > -999
        
        // Only show measurement when both hands are tracked
        guard isLeftTracked && isRightTracked else {
            line.isEnabled = false
            resultBoard?.isEnabled = false
            return
        }
        
        let centerPosition = (leftPos + rightPos) / 2
        let length = distance(leftPos, rightPos)
        
        // Only show the line if there's a meaningful distance
        if length > 0.005 { // Increased threshold
            line.position = centerPosition
            line.components.set(ModelComponent(
                mesh: .generateBox(
                    width: 0.003,
                    height: 0.003,
                    depth: length,
                    cornerRadius: 0.001
                ),
                materials: [SimpleMaterial(color: .yellow, roughness: 0.2, isMetallic: false)]
            ))
            
            line.look(at: leftPos, from: centerPosition, relativeTo: nil)
            line.isEnabled = true
            resultBoard?.isEnabled = true
        } else {
            line.isEnabled = false
            resultBoard?.isEnabled = false
        }
        
        // Position the result board above the center point
        resultBoard?.setPosition(centerPosition + SIMD3<Float>(0, 0.1, 0), relativeTo: nil)
    }
    
    func getResultString() -> String {
        guard let leftTip = fingerTips[.left],
              let rightTip = fingerTips[.right] else { return "No entities" }
        
        let leftPos = leftTip.position
        let rightPos = rightTip.position
        
        let isLeftTracked = leftPos.x > -999 && leftPos.y > -999 && leftPos.z > -999
        let isRightTracked = rightPos.x > -999 && rightPos.y > -999 && rightPos.z > -999
        
        guard isLeftTracked && isRightTracked else {
            return "Show both hands to camera"
        }
        
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.numberFormatter.minimumFractionDigits = 2
        formatter.numberFormatter.maximumFractionDigits = 2
        
        let length = distance(leftPos, rightPos)
        
        if length < 0.005 {
            return " index fingers"
        }
        
        // Convert to more appropriate units based on distance
        if length < 0.01 {
            // Show in millimeters for small distances
            return formatter.string(from: .init(value: Double(length * 1000), unit: UnitLength.millimeters))
        } else if length < 1.0 {
            // Show in centimeters for medium distances
            return formatter.string(from: .init(value: Double(length * 100), unit: UnitLength.centimeters))
        } else {
            // Show in meters for large distances
            return formatter.string(from: .init(value: Double(length), unit: UnitLength.meters))
        }
    }
}
