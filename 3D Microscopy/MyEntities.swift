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
        fingerTips = [
            .left: ModelEntity(mesh: .generateSphere(radius: 0.01), materials: [SimpleMaterial()]),
            .right: ModelEntity(mesh: .generateSphere(radius: 0.01), materials: [SimpleMaterial()])
        ]
        fingerTips.values.forEach { root.addChild($0) }
        
        line.components.set(OpacityComponent(opacity: 0.75))
        
        root.addChild(line)
    }
    
    func add(_ resultBoardEntity: Entity) {
        resultBoard = resultBoardEntity
        root.addChild(resultBoardEntity)
    }
    
    func update() {
        let centerPosition = (fingerTips[.left]!.position + fingerTips[.right]!.position) / 2
        let length = distance(fingerTips[.left]!.position, fingerTips[.right]!.position)
        
        line.position = centerPosition
        line.components.set(ModelComponent(mesh: .generateBox(width: 0.01,
                                                              height: 0.01,
                                                              depth: length,
                                                              cornerRadius: 0.005),
                                           materials: [SimpleMaterial()]))
        line.look(at: fingerTips[.left]!.position, from: centerPosition, relativeTo: nil)
        
        resultBoard?.setPosition(centerPosition, relativeTo: nil)
    }
    
    func getResultString() -> String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.numberFormatter.minimumFractionDigits = 2
        formatter.numberFormatter.maximumFractionDigits = 2
        let length = distance(fingerTips[.left]!.position, fingerTips[.right]!.position)
        return formatter.string(from: .init(value: .init(length), unit: UnitLength.meters))
    }
}
