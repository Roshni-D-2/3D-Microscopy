import SwiftUI
import RealityKit

@main
struct _D_MicroscopyApp: SwiftUI.App {
    @StateObject private var model = AppModel()

    var body: some SwiftUI.Scene {
        // 2D importer / selection UI
        WindowGroup(id: "MainWindow") {
            ContentView()
                .environmentObject(model)
        }
        .windowStyle(.plain)

        // immersive fingertip-measurement view
        ImmersiveSpace(id: model.immersiveSpaceID) {
            RealityView { content, attachments in
                // only show measurement entities when "on"
                if model.isOn {
                    content.add(model.myEntities.root)
                }
                // always hook up the floating result board
                if let board = attachments.entity(for: "resultBoard") {
                    model.myEntities.add(board)
                }
            } attachments: {
                // on/off toggle
                Attachment(id: "measureSwitch") {
                    Toggle("Measure", isOn: $model.isOn)
                        .padding()
                        .glassBackgroundEffect()
                        .offset(y: -120)
                }
                // result label (only when on)
                Attachment(id: "resultBoard") {
                    if model.isOn {
                        Text(model.resultString)
                            .monospacedDigit()
                            .padding()
                            .glassBackgroundEffect()
                            .offset(y: -80)
                    }
                }
            }
            // <-- these .task modifiers must come *after* the attachments block
            .task { await model.runSession() }
            .task { await model.processAnchorUpdates() }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
