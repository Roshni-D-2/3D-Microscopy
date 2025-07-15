

import SwiftUI
import RealityKit

struct ImmersiveView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var modelEntity: Entity? = nil
//    @Environment(\.openWindow) private var openWindow
    @GestureState private var dragOffset: CGSize = .zero
    @State private var lastDragPosition: SIMD3<Float>? = nil


    var body: some View {
        gestureWrapper(for: modelEntity) {
            RealityView { content in
                // Add model once loaded
            } update: { content in
                if let entity = modelEntity, content.entities.isEmpty {
                    content.add(entity)
                }
            }
        }
        .task {
            guard let modelURL = appModel.modelURL else { return }
            do {
                let rawEntity = try await Entity(contentsOf: modelURL)
                rawEntity.components.set(InputTargetComponent())
                rawEntity.generateCollisionShapes(recursive: true)
                let wrappedEntity = centerEntity(rawEntity)
                wrappedEntity.setPosition([0, 1, -1], relativeTo: nil)
                modelEntity = wrappedEntity
                
//                openWindow(id: "GestureControlPanel")
            } catch {
                print("Failed to load model: \(error.localizedDescription)")
            }
        }
    }

    // Center the model
    func centerEntity(_ entity: Entity) -> Entity {
        let anchor = Entity()
        let bounds = entity.visualBounds(relativeTo: nil)
        let center = bounds.center
        entity.position -= center
        anchor.addChild(entity)
        return anchor
    }
    // Wrap the view in gestures based on mode
       @ViewBuilder
       func gestureWrapper<Content: View>(for entity: Entity?, @ViewBuilder content: () -> Content) -> some View {
           switch appModel.gestureMode {
               //hopefully smoother drag
           case .drag:
               content()
                   .gesture(
                       DragGesture()
                           .updating($dragOffset) { value, state, _ in
                               state = value.translation
                           }
                           .onChanged { value in
                               guard let entity = entity else { return }

                               // Convert translation to Float
                               let currentX = Float(value.translation.width)
                               let currentZ = Float(value.translation.height)

                               let lastX = lastDragPosition?.x ?? 0
                               let lastZ = lastDragPosition?.z ?? 0

                               let deltaX = (currentX - lastX) * 0.001
                               let deltaZ = (lastZ - currentZ) * 0.001 // negative to go in correct direction

                               entity.position += SIMD3<Float>(deltaX, 0, deltaZ)

                               // Update last position
                               lastDragPosition = SIMD3<Float>(currentX, 0, currentZ)
                           }
                           .onEnded { _ in
                               lastDragPosition = nil
                           }
                   )
               
               // smoothed rotation with better control
               case .rotate:
                   content().gesture(
                       DragGesture()
                           .onChanged { value in
                               guard let entity = entity else { return }
                               let sensitivity: Float = 0.003  // smaller = slower rotation
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
               content().gesture(
                   SpatialTapGesture().targetedToAnyEntity().onEnded { value in
                       print("📏 Measurement feature placeholder – tapped \(value.entity.name)")
                   }
               )

           default:
               content() // No gesture
           }
       }
}
