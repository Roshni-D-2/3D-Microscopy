import SwiftUI
import RealityKit

struct ImmersiveView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var modelEntity: Entity? = nil

    var body: some View {
        RealityView { content, attachments in
            // 1️⃣ Add your hand‐tracking “root” (spheres + line)
            content.add(appModel.myEntities.root)

            // 2️⃣ Add the imported 3D model, once it’s loaded
            if let entity = modelEntity {
                content.add(entity)
            }

            // 3️⃣ Hook up the floating result‐board attachment
            if let board = attachments.entity(for: "resultBoard") {
                appModel.myEntities.add(board)
            }
        } attachments: {
            // This SwiftUI view will track to “resultBoard” in the scene
            Attachment(id: "resultBoard") {
                Text(appModel.resultString)
                    .monospacedDigit()
                    .padding()
                    .glassBackgroundEffect()
                    .offset(y: -80)
            }
        }
        // Allow full 6-DOF gestures on your imported model
        .useFullGesture(constrainedToAxis: .x)
        // Kick off hand‐tracking, then process its anchor updates indefinitely:
        .task {
            await appModel.runSession()
            await appModel.processAnchorUpdates()
        }
        // Watch for a new modelURL and load that .obj into the scene
        .task(id: appModel.modelURL) {
            guard let modelURL = appModel.modelURL else { return }
            do {
                let raw = try await Entity(contentsOf: modelURL)
                raw.components.set(InputTargetComponent())
                raw.generateCollisionShapes(recursive: true)
                let centered = centerEntity(raw)
                // Position it out in front of you
                centered.setPosition([0, 1, -1], relativeTo: nil)
                modelEntity = centered
            } catch {
                print("Failed to load model: \(error.localizedDescription)")
            }
        }
    }

    /// Wraps an entity in a parent and recenters its visualBounds
    private func centerEntity(_ entity: Entity) -> Entity {
        let anchor = Entity()
        let bounds = entity.visualBounds(relativeTo: nil)
        let center = bounds.center
        entity.position -= center
        anchor.addChild(entity)
        return anchor
    }
}
