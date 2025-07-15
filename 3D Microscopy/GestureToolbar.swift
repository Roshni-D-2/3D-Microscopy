//
//  GestureToolbar.swift
//  3D Microscopy
//
//  Created by Future Lab XR1 on 7/15/25.
//


import SwiftUI

struct GestureToolbar: View {
    @EnvironmentObject var appModel: AppModel


    var body: some View {
        HStack(spacing: 16) {
            ForEach(GestureMode.allCases, id: \.self) { mode in
                Button {
                    appModel.gestureMode = mode
                } label : {
                    Text(mode.rawValue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(appModel.gestureMode == mode ? Color.purple.opacity(0.8) : Color.gray.opacity(0.2))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }
}
