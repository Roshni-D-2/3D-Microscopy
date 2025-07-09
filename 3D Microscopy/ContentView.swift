//
//  ContentView.swift
//  3D Microscopy
//
//  Created by Future Lab XR1 on 7/8/25.
//

import SwiftUI
import RealityKit
import RealityKitContent
import UniformTypeIdentifiers



struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var models: [URL] = []

    var body: some View {
        VStack(spacing: 20) {
            Text("Immersive Microscopy Viewer")
                .font(.largeTitle)
                .bold()

            Button("Refresh Model List") {
                print("refresh model list")
                loadAvailableModels()
            }
            .padding()
            .background(Color.gray)
            .foregroundColor(.white)
            .cornerRadius(10)

            List(appModel.availableModels, id: \.self) { modelURL in
                Button(modelURL.lastPathComponent) {
                    appModel.modelURL = modelURL
                    print("loading model url")
                }
            }
            .frame(height: 200)
            
            ToggleImmersiveSpaceButton()
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .onAppear(){
            loadAvailableModels()
        }
    }
    func loadAvailableModels() {
        print("load function called")
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        //dummy file top create documents file in xcapp
        let dummyPath = docsURL.appendingPathComponent("dummy.txt")
        if !FileManager.default.fileExists(atPath: dummyPath.path) {
            try? "initialized".write(to: dummyPath, atomically: true, encoding: .utf8)
        }
        //actually load models into content view
        do {
            let files = try FileManager.default.contentsOfDirectory(at: docsURL, includingPropertiesForKeys: nil)
            let objFiles = files.filter { $0.pathExtension == "obj" }
            print("Files found:", objFiles.map(\.lastPathComponent))
            appModel.availableModels = objFiles
            print(appModel.availableModels)
        } catch {
            print("Failed to load models: \(error)")
        }
    }
}
