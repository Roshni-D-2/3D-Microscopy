//
//  _D_MicroscopyApp.swift
//  3D Microscopy
//
//  Created by Future Lab XR1 in 2025.
//

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
                .environmentObject(appModel)
        }
        .windowStyle(.plain)
        
        //open immersive
        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
            //toggles state view
                .environmentObject(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                    print("Immersive appeared. isOn: \(appModel.isOn), modelURL: \(String(describing: appModel.modelURL))")
                
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.full), in: .full) // immersive for VR
        
        // instantiating toolbar
        WindowGroup(id: "GestureControlPanel") {
            GestureToolbar()
                .environmentObject(appModel)
        }
        .windowStyle(.plain)
        .defaultSize(width: 1200, height: 100) // Made wider to accommodate new button
        
        // Measurement tutorial
        WindowGroup(id: "TutorialView") {
            TutorialView()
                .environmentObject(appModel)
        }
        
        // Annotation tutorial
        WindowGroup(id: "AnnotationTutorialView") {
            AnnotationTutorialView()
                .environmentObject(appModel)
        }
        
        // Annotation text input window
        WindowGroup(id: "AnnotationInput") {
            AnnotationInputView(annotationManager: appModel.annotationManager)
                .environmentObject(appModel)
        }
        .windowStyle(.plain)
        .defaultSize(width: 450, height: 500)
        
        // Annotation controls overlay (for annotation mode)
        WindowGroup(id: "AnnotationControls") {
            AnnotationControlsView(annotationManager: appModel.annotationManager)
                .environmentObject(appModel)
        }
        .windowStyle(.plain)
        .defaultSize(width: 200, height: 150)
    }
}
