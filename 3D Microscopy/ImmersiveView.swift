import SwiftUI
import RealityKit

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
                    let rawEntity = try await Entity(contentsOf: modelURL)
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
                        let sensitivity: Float = 0.003
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
            
        case .crop:
            content()
        default:
            content() // No gesture
        }
    }
}
