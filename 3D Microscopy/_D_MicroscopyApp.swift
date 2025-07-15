import SwiftUI
//import RealityKit
//import RealityKitContent


@main
struct _D_MicroscopyApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup(id: "MainWindow") {
            ContentView()
                .environmentObject(appModel)
        }
        .windowStyle(.plain)

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environmentObject(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)

        // ✅ Add this
        WindowGroup(id: "GestureControlPanel") {
            GestureToolbar()
                .environmentObject(appModel)
        }
        .defaultSize(width: 800, height: 100) // Optional
        .windowStyle(.plain) // Optional
    }
}

