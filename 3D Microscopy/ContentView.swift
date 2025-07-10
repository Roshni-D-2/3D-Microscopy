import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var showImporter = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Immersive Microscopy Viewer")
                .font(.largeTitle)
                .bold()

            Button("Import Model File") {
                showImporter = true
            }
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)

            // This button toggles you into the immersive space above
            ToggleImmersiveSpaceButton()
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)

            List(appModel.availableModels, id: \.self) { modelURL in
                Button(modelURL.lastPathComponent) {
                    appModel.modelURL = modelURL
                }
            }
            .frame(height: 200)
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [UTType(filenameExtension: "obj")!],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let selectedURL = urls.first {
                    copyToDocuments(originalURL: selectedURL)
                    loadAvailableModels()
                }
            case .failure(let error):
                print("Import failed: \(error.localizedDescription)")
            }
        }
        .onAppear {
            loadAvailableModels()
        }
    }

    // MARK: – Helpers

    private func loadAvailableModels() {
        let docsURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
        do {
            let files = try FileManager.default
                .contentsOfDirectory(at: docsURL, includingPropertiesForKeys: nil)
            appModel.availableModels = files
                .filter { $0.pathExtension.lowercased() == "obj" }
        } catch {
            print("Failed to load models: \(error)")
        }
    }

    private func copyToDocuments(originalURL: URL) {
        let docsURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
        let destURL = docsURL.appendingPathComponent(originalURL.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: originalURL, to: destURL)
        } catch {
            print("Copy failed: \(error)")
        }
    }
}
