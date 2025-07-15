

import SwiftUI
import RealityKit

struct ImmersiveView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var modelEntity: Entity? = nil
//    @Environment(\.openWindow) private var openWindow


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
           case .drag:
               content().gesture(
                   DragGesture().onChanged { value in
                       if let entity = entity {
                           let translation = SIMD3<Float>(
                               Float(value.translation.width / 300),
                               0,
                               Float(-value.translation.height / 300)
                           )
                           entity.position += translation
                       }
                   }
               )

           case .rotate:
               content().gesture(
                   DragGesture().onChanged { value in
                       if let entity = entity {
                           let angle = Float(value.translation.width / 200.0)
                           entity.transform.rotation *= simd_quatf(angle: angle, axis: [0, 1, 0])
                       }
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
