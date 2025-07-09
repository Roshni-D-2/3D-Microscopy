//
//  _D_MicroscopyApp.swift
//  3D Microscopy
//
//  Created by Future Lab XR1 on 7/8/25.
//

import SwiftUI

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
    }
}
