//
//  ImmersiveView.swift
//  3D Microscopy
//
//  Created by Future Lab XR1 in 2025.
//

import SwiftUI
import RealityKit
import simd

struct ImmersiveView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var modelEntity: Entity? = nil
    @Environment(\.openWindow) private var openWindow
    
    //vars for drag gesture
    @GestureState private var dragOffset: CGSize = .zero
    @State private var lastDragPosition: SIMD3<Float>? = nil
    
    // Add a state variable to force RealityView updates
    @State private var updateTrigger: Bool = false
    
    var body: some View {
        gestureWrapper(for: modelEntity) {
            RealityView { content, attachments in
                // Add hand-tracking root entities
                if appModel.isOn {
                    print("Adding measuring bar root entity")
                    content.add(appModel.myEntities.root)
                }
                // Add model once it's loaded
                if let entity = modelEntity {
                    print("added model")
                    content.add(entity)
                }
                
                // Add result board overlay if available
                if let board = attachments.entity(for: "resultBoard") {
                    appModel.myEntities.add(board)
                }
                
                // Add annotation controls overlay for annotation mode
                if let controls = attachments.entity(for: "annotationControls") {
                    controls.position = [0.5, 0.3, -0.5] // Position in front of user
                    content.add(controls)
                }
            } update: { content, attachments in
                // This update block runs when updateTrigger changes
                
                // Clear existing content except for hand tracking
                content.entities.removeAll { entity in
                    entity != appModel.myEntities.root
                }
                
                // Re-add model if it exists
                if let entity = modelEntity {
                    content.add(entity)
                }
                
                // Handle hand tracking visibility
                if appModel.isOn && !content.entities.contains(appModel.myEntities.root) {
                    content.add(appModel.myEntities.root)
                } else if !appModel.isOn && content.entities.contains(appModel.myEntities.root) {
                    content.remove(appModel.myEntities.root)
                }
                
                // Update annotation controls visibility
                if let controls = attachments.entity(for: "annotationControls") {
                    if appModel.gestureMode == .annotate && appModel.isOn {
                        controls.position = [0.5, 0.3, -0.5]
                        if !content.entities.contains(controls) {
                            content.add(controls)
                        }
                    } else {
                        content.remove(controls)
                    }
                }
            } attachments: {
                // Attachment for floating result display
                Attachment(id: "resultBoard") {
                    Text(appModel.resultString)
                        .monospacedDigit()
                        .padding()
                        .glassBackgroundEffect()
                        .offset(y: -80)
                }
                
                // Attachment for annotation controls (only visible in annotation mode)
                if appModel.gestureMode == .annotate {
                    Attachment(id: "annotationControls") {
                        AnnotationControlsView(annotationManager: appModel.annotationManager)
                            .environmentObject(appModel)
                    }
                }
            }
        }
        // Add updateTrigger as an id to force RealityView updates
        .id(updateTrigger)
        // Kick off hand‐tracking session and anchor updates
        .task {
            await appModel.runSession()
        }
        .task {
            // Process anchor updates continuously
            await appModel.processAnchorUpdates()
        }
        // Watch for modelURL changes and load model
        .task(id: appModel.modelURL) {
            // Load model if not already loaded and modelURL exists
            if let modelURL = appModel.modelURL {
                do {
                    let rawEntity = try await ModelEntity(contentsOf: modelURL)
                    rawEntity.components.set(InputTargetComponent())
                    rawEntity.generateCollisionShapes(recursive: true)
                    let wrappedEntity = centerEntity(rawEntity)
                    wrappedEntity.setPosition([0, 1, -1], relativeTo: nil)
                    modelEntity = wrappedEntity
                    
                    // Toggle updateTrigger to force RealityView to re-render
                    updateTrigger.toggle()
                    
                    print("Model loaded !!")
                } catch {
                    print("Failed to load model: \(error.localizedDescription)")
                }
            }
        }
        // Watch for changes to isOn and trigger update
        .onChange(of: appModel.isOn) { _, _ in
            updateTrigger.toggle()
        }
        // Watch for gesture mode changes
        .onChange(of: appModel.gestureMode) { _, _ in
            updateTrigger.toggle()
        }
        // Handle pending annotation creation
        .onChange(of: appModel.pendingAnnotationPosition) { _, newPosition in
            if newPosition != nil {
                // Open annotation input window when a new annotation is requested
                openWindow(id: "AnnotationInput")
            }
        }
    }
    
    // Center the model by wrapping it in an anchor
    func centerEntity(_ entity: Entity) -> Entity {
        let anchor = Entity()
        let bounds = entity.visualBounds(relativeTo: nil)
        let center = bounds.center
        entity.position -= center
        anchor.addChild(entity)
        return anchor
    }
    
    // Custom gesture wrapper for different modes
    @ViewBuilder
    func gestureWrapper<Content: View>(for entity: Entity?, @ViewBuilder content: () -> Content) -> some View {
        switch appModel.gestureMode {
        case .drag:
            content()
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation
                        }
                        .onChanged { value in
                            guard let entity = entity else { return }
                            
                            let currentX = Float(value.translation.width)
                            let currentZ = Float(value.translation.height)
                            
                            let lastX = lastDragPosition?.x ?? 0
                            let lastZ = lastDragPosition?.z ?? 0
                            
                            let deltaX = (currentX - lastX) * 0.001
                            let deltaZ = (lastZ - currentZ) * 0.001
                            
                            entity.position += SIMD3<Float>(deltaX, 0, deltaZ)
                            
                            lastDragPosition = SIMD3<Float>(currentX, 0, currentZ)
                        }
                        .onEnded { _ in
                            lastDragPosition = nil
                        }
                )
            
        case .rotate:
            content().gesture(
                DragGesture()
                    .onChanged { value in
                        guard let entity = entity else { return }
                        let sensitivity: Float = 0.001
                        let angle = Float(value.translation.width) * sensitivity
                        let rotation = simd_quatf(angle: angle, axis: [0, 1, 0])
                        entity.transform.rotation = rotation * entity.transform.rotation
                    }
            )
            
        case .scale:
            content().gesture(
                MagnificationGesture().onChanged { value in
                    if let entity = entity {
                        entity.transform.scale = [Float(value), Float(value), Float(value)]
                    }
                }
            )
            
        case .measure:
            content()
                .gesture(
                    // Single tap to place measurement
                    TapGesture()
                        .onEnded { _ in
                            appModel.myEntities.placeMeasurement()
                        }
                )
                .gesture(
                    // Double tap to remove last measurement
                    TapGesture(count: 2)
                        .onEnded { _ in
                            appModel.myEntities.removeLastMeasurement()
                        }
                )
                .gesture(
                    // Long press to clear all measurements
                    LongPressGesture(minimumDuration: 1.0)
                        .onEnded { _ in
                            appModel.myEntities.clearAllMeasurements()
                        }
                )
        
        case .annotate:
            content()
                .onTapGesture { location in
                    // Handle tap on existing annotations or create new ones
                    // For now, we rely on pinch gestures for annotation creation
                    // This could be extended to handle tap-to-select annotations
                    print("Tap in annotation mode at: \(location)")
                }
                .gesture(
                    // Long press to clear all annotations
                    LongPressGesture(minimumDuration: 1.0)
                        .onEnded { _ in
                            appModel.clearAllAnnotations()
                        }
                )
            
            // MARK: - Improved Crop Gesture Implementation
            
        case .crop:
            content()
        default:
            content() // No gesture
        }
    }
}
//                .simultaneousGesture(
//                    DragGesture(minimumDistance: 10)
//                        .onChanged { value in
//                            guard let entity = entity else { return }
//                            
//                            if !appModel.isDrawingCropLine {
//                                print("Starting crop line drawing")
//                                appModel.isDrawingCropLine = true
//                                appModel.cropStartPoint = convertScreenToWorld(value.startLocation, entity: entity)
//                                createCropPreview(entity: entity)
//                            }
//                            
//                            appModel.cropEndPoint = convertScreenToWorld(value.location, entity: entity)
//                            updateCropPreview(entity: entity)
//                        }
//                        .onEnded { value in
//                            print("Crop gesture ended")
//                            guard let entity = entity else { return }
//                            
//                            if let startPoint = appModel.cropStartPoint,
//                               let endPoint = appModel.cropEndPoint {
//                                print("Applying crop from \(startPoint) to \(endPoint)")
//                                Task {
//                                    await applyCrop(to: entity, startPoint: startPoint, endPoint: endPoint)
//                                }
//                            }
//                            
//                            cleanupCropState()
//                        }
//                )
//        }
//    }
//            // MARK: - Helper function to clean up crop state
//            func cleanupCropState() {
//                appModel.cleanupCropPreview()
//                appModel.isDrawingCropLine = false
//                appModel.cropStartPoint = nil
//                appModel.cropEndPoint = nil
//            }
//            
//            // MARK: - Improved Preview Creation
//            func createCropPreview(entity: Entity) {
//                print("createCropPreview called")
//                
//                // Clean up any existing preview first
//                appModel.cleanupCropPreview()
//                
//                do {
//                    // Create a thin line mesh for the cutting preview
//                    let previewMaterial = UnlitMaterial(color: .red)
//                    previewMaterial.baseColor = .init(tint: .red.withAlphaComponent(0.8))
//                    
//                    // Start with a small box that we'll scale
//                    let previewMesh = MeshResource.generateBox(size: [0.005, 0.005, 0.1])
//                    
//                    appModel.cropPreviewEntity = ModelEntity(mesh: previewMesh, materials: [previewMaterial])
//                    appModel.cropPreviewEntity?.name = "crop_preview"
//                    
//                    // Add to the same parent as the model entity
//                    if let parent = entity.parent {
//                        parent.addChild(appModel.cropPreviewEntity!)
//                    } else {
//                        // Find the root content entity to add to
//                        var currentEntity = entity
//                        while let parent = currentEntity.parent {
//                            currentEntity = parent
//                        }
//                        currentEntity.addChild(appModel.cropPreviewEntity!)
//                    }
//                    
//                    print("Created and added preview entity")
//                    
//                } catch {
//                    print("Error creating preview: \(error)")
//                }
//            }
//            
//            // MARK: - Improved Preview Update
//            func updateCropPreview(entity: Entity) {
//                guard let previewEntity = appModel.cropPreviewEntity,
//                      let startPoint = appModel.cropStartPoint,
//                      let endPoint = appModel.cropEndPoint else {
//                    return
//                }
//                
//                // Calculate line properties
//                let center = (startPoint + endPoint) / 2
//                let direction = endPoint - startPoint
//                let length = simd_length(direction)
//                
//                // Avoid zero-length lines
//                guard length > 0.001 else { return }
//                
//                let normalizedDirection = direction / length
//                
//                // Position the preview line
//                previewEntity.position = center
//                
//                // Scale the line to match the drag distance
//                previewEntity.transform.scale = SIMD3<Float>(1, 1, length * 10) // Scale Z-axis for length
//                
//                // Orient the line along the drag direction
//                // Create rotation to align Z-axis with the drag direction
//                let forward = SIMD3<Float>(0, 0, 1)
//                let targetDirection = SIMD3<Float>(normalizedDirection.x, 0, normalizedDirection.z)
//                
//                if simd_length(targetDirection) > 0.001 {
//                    let normalizedTarget = simd_normalize(targetDirection)
//                    let dotProduct = simd_dot(forward, normalizedTarget)
//                    
//                    if abs(dotProduct - 1.0) > 0.001 { // Not already aligned
//                        let axis = simd_cross(forward, normalizedTarget)
//                        if simd_length(axis) > 0.001 {
//                            let angle = acos(simd_clamp(dotProduct, -1.0, 1.0))
//                            previewEntity.transform.rotation = simd_quatf(angle: angle, axis: simd_normalize(axis))
//                        }
//                    }
//                }
//            }
//            
//            // MARK: - Improved Screen to World Conversion
//            func convertScreenToWorld(_ screenPoint: CGPoint, entity: Entity) -> SIMD3<Float> {
//                // For visionOS, we need to work in the entity's coordinate space
//                let bounds = entity.visualBounds(relativeTo: entity.parent)
//                let entityCenter = bounds.center
//                let entitySize = bounds.max - bounds.min
//                
//                // Convert screen coordinates to normalized device coordinates
//                // Assuming screen space is roughly 0-1000 points in each direction
//                let normalizedX = Float(screenPoint.x / 1000.0 - 0.5) // -0.5 to 0.5
//                let normalizedY = Float(screenPoint.y / 1000.0 - 0.5) // -0.5 to 0.5
//                
//                // Map to entity space (assuming we're looking down the Z-axis)
//                let worldX = entityCenter.x + normalizedX * entitySize.x
//                let worldZ = entityCenter.z + normalizedY * entitySize.z
//                let worldY = entityCenter.y // Keep same Y level as entity center
//                
//                let worldPoint = SIMD3<Float>(worldX, worldY, worldZ)
//                print("Screen \(screenPoint) -> World \(worldPoint)")
//                return worldPoint
//            }
//            
//            // MARK: - Enhanced Mesh Slicing
//            func sliceMesh(
//                meshContents: MeshResource.Contents,
//                planeCenter: SIMD3<Float>,
//                planeNormal: SIMD3<Float>
//            ) async throws -> (MeshResource, MeshResource) {
//                
//                guard let model = meshContents.models.first,
//                      let part = model.parts.first else {
//                    throw NSError(domain: "MeshSlicing", code: 1, userInfo: [NSLocalizedDescriptionKey: "No mesh data found"])
//                }
//                
//                let positions = part.positions.elements
//                let indices = part.triangleIndices?.elements ?? []
//                
//                guard positions.count > 0 && indices.count > 0 else {
//                    throw NSError(domain: "MeshSlicing", code: 2, userInfo: [NSLocalizedDescriptionKey: "Empty mesh data"])
//                }
//                
//                var leftVertices: [SIMD3<Float>] = []
//                var rightVertices: [SIMD3<Float>] = []
//                var leftIndices: [UInt32] = []
//                var rightIndices: [UInt32] = []
//                
//                // Process triangles with improved slicing
//                for i in stride(from: 0, to: indices.count, by: 3) {
//                    let idx1 = Int(indices[i])
//                    let idx2 = Int(indices[i + 1])
//                    let idx3 = Int(indices[i + 2])
//                    
//                    let v1 = positions[idx1]
//                    let v2 = positions[idx2]
//                    let v3 = positions[idx3]
//                    
//                    // Calculate signed distances from plane
//                    let d1 = dot(v1 - planeCenter, planeNormal)
//                    let d2 = dot(v2 - planeCenter, planeNormal)
//                    let d3 = dot(v3 - planeCenter, planeNormal)
//                    
//                    // Classify vertices
//                    let leftMask = (d1 <= 0 ? 1 : 0) + (d2 <= 0 ? 2 : 0) + (d3 <= 0 ? 4 : 0)
//                    
//                    switch leftMask {
//                    case 0: // All vertices on right side
//                        addTriangle(vertices: [v1, v2, v3], to: &rightVertices, indices: &rightIndices)
//                        
//                    case 7: // All vertices on left side
//                        addTriangle(vertices: [v1, v2, v3], to: &leftVertices, indices: &leftIndices)
//                        
//                    default: // Triangle intersects plane - for now, assign to majority side
//                        let leftCount = (d1 <= 0 ? 1 : 0) + (d2 <= 0 ? 1 : 0) + (d3 <= 0 ? 1 : 0)
//                        if leftCount >= 2 {
//                            addTriangle(vertices: [v1, v2, v3], to: &leftVertices, indices: &leftIndices)
//                        } else {
//                            addTriangle(vertices: [v1, v2, v3], to: &rightVertices, indices: &rightIndices)
//                        }
//                    }
//                }
//                
//                // Ensure both sides have geometry
//                if leftVertices.isEmpty {
//                    addTriangle(vertices: [
//                        planeCenter + planeNormal * -0.001,
//                        planeCenter + planeNormal * -0.001 + SIMD3<Float>(0.01, 0, 0),
//                        planeCenter + planeNormal * -0.001 + SIMD3<Float>(0, 0.01, 0)
//                    ], to: &leftVertices, indices: &leftIndices)
//                }
//                
//                if rightVertices.isEmpty {
//                    addTriangle(vertices: [
//                        planeCenter + planeNormal * 0.001,
//                        planeCenter + planeNormal * 0.001 + SIMD3<Float>       (0.01, 0, 0),
//                        planeCenter + planeNormal * 0.001 + SIMD3<Float>(0, 0.01, 0)
//                    ], to: &rightVertices, indices: &rightIndices)
//                }
//                
//                print("Slicing complete: Left=\(leftVertices.count) vertices, Right=\(rightVertices.count) vertices")
//                
//                // Create new mesh resources
//                let leftMesh = try MeshResource.generate(from: leftVertices as! [MeshDescriptor], indices: leftIndices)
//                let rightMesh = try MeshResource.generate(from: rightVertices as! [MeshDescriptor], indices: rightIndices)
//                
//                return (leftMesh, rightMesh)
//            }
//            
//            // MARK: - Helper function to add triangle
//            func addTriangle(vertices: [SIMD3<Float>], to vertexArray: inout [SIMD3<Float>], indices: inout [UInt32]) {
//                let baseIndex = UInt32(vertexArray.count)
//                vertexArray.append(contentsOf: vertices)
//                indices.append(contentsOf: [baseIndex, baseIndex + 1, baseIndex + 2])
//            }
//            
//            // MARK: - Improved Entity Creation
//            func createSlicedEntities(
//                originalEntity: ModelEntity,
//                leftMesh: MeshResource,
//                rightMesh: MeshResource,
//                planeNormal: SIMD3<Float>
//            ) {
//                // Get original materials or create default
//                let materials = originalEntity.model?.materials ?? [SimpleMaterial(color: .gray, isMetallic: false)]
//                
//                // Create left half with slight offset
//                let leftEntity = ModelEntity(mesh: leftMesh, materials: materials)
//                leftEntity.name = "sliced_left"
//                leftEntity.transform = originalEntity.transform
//                leftEntity.position = originalEntity.position + (planeNormal * -0.02)
//                leftEntity.components.set(InputTargetComponent())
//                leftEntity.generateCollisionShapes(recursive: true)
//                
//                // Create right half with slight offset
//                let rightEntity = ModelEntity(mesh: rightMesh, materials: materials)
//                rightEntity.name = "sliced_right"
//                rightEntity.transform = originalEntity.transform
//                rightEntity.position = originalEntity.position + (planeNormal * 0.02)
//                rightEntity.components.set(InputTargetComponent())
//                rightEntity.generateCollisionShapes(recursive: true)
//                
//                // Replace original with sliced parts
//                if let parent = originalEntity.parent {
//                    parent.addChild(leftEntity)
//                    parent.addChild(rightEntity)
//                    originalEntity.removeFromParent()
//                    
//                    // Update the modelEntity reference to one of the pieces (or keep both)
//                    modelEntity = leftEntity // or create a container entity
//                    
//                    print("Successfully created sliced entities")
//                } else {
//                    print("Error: Original entity has no parent")
//                }
//            }
//        }
