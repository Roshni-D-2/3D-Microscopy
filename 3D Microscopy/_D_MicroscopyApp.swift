import SwiftUI
//import RealityKit //why does this cause errors.
import RealityKitContent

@main
struct _D_MicroscopyApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        //main screen launch
        WindowGroup(id: "MainWindow") {
            ContentView()
                .environmentObject(model)
        }
        .windowStyle(.plain)
//open immersive
        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
            //toggles state view
                .environmentObject(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        
        // instantiating toolbar
        WindowGroup(id: "GestureControlPanel") {
            GestureToolbar()
                .environmentObject(appModel)
//                .offset(y: 100)
        }
        .windowStyle(.plain)
        //needs to be wider
        .defaultSize(width: 800, height: 100)
    }
}

