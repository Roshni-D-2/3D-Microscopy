import SwiftUI
import RealityKit
//import UmainSpatialGestures // Import the gesture extension

struct ImmersiveView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var modelEntity: Entity? = nil

    var body: some View {
        RealityView { content in
            // Start empty, we'll add entities dynamically
        } update: { content in
            if let entity = modelEntity, content.entities.isEmpty {
                content.add(entity)
            }
        }
        //.useRotateGesture(constrainedToAxis: .y)
        .useFullGesture(constrainedToAxis: .x)
        .task {
            guard let modelURL = appModel.modelURL else { return }
            do {
                let rawEntity = try await Entity(contentsOf: modelURL)
                rawEntity.components.set(InputTargetComponent())
                rawEntity.generateCollisionShapes(recursive: true)
                let wrappedEntity = centerEntity(rawEntity)
                wrappedEntity.setPosition([0, 1, -1], relativeTo: nil)
                modelEntity = wrappedEntity
            } catch {
                print("Failed to load model: \(error.localizedDescription)")
            }
        }
    }

    func centerEntity(_ entity: Entity) -> Entity {
        let anchor = Entity()
        let bounds = entity.visualBounds(relativeTo: nil)
        let center = bounds.center
        entity.position -= center
        anchor.addChild(entity)
        return anchor
    }
}
