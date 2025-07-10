import SwiftUI
import RealityKit

@main
struct _D_MicroscopyApp: SwiftUI.App {
    @StateObject private var model = AppModel()

    // explicitly tell the compiler you mean SwiftUI.Scene
    var body: some SwiftUI.Scene {
        // 2D importer / selection UI
        WindowGroup(id: "MainWindow") {
            ContentView()
                .environmentObject(model)
        }
        .windowStyle(.plain)      // now correctly applies to the SwiftUI WindowGroup

        // immersive fingertip-measurement view
        ImmersiveSpace(id: model.immersiveSpaceID) {
            RealityView { content, attachments in
                content.add(model.myEntities.root)
                if let board = attachments.entity(for: "resultBoard") {
                    model.myEntities.add(board)
                }
            } attachments: {
                Attachment(id: "resultBoard") {
                    Text(model.resultString)
                        .monospacedDigit()
                        .padding()
                        .glassBackgroundEffect()
                        .offset(y: -80)
                }
            }
            .task { await model.runSession() }
            .task { await model.processAnchorUpdates() }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
