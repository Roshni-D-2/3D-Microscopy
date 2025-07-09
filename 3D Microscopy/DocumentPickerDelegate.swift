//
//  DocumentPickerDelegate.swift
//  3D Microscopy
//
//  Created by Future Lab XR1 on 7/8/25.
//
// DocumentPickerDelegate.swift
import UIKit

class DocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
    private let onPick: (URL) -> Void

    init(onPick: @escaping (URL) -> Void) {
        self.onPick = onPick
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if let url = urls.first {
            onPick(url)
        }
    }
}
