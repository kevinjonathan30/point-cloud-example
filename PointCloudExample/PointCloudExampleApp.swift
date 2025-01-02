//
//  PointCloudExampleApp.swift
//  PointCloudExample
//
//  Created by Kevin Jonathan on 2025/01/02.
//

import SwiftUI

struct UIViewWrapper<V: UIView>: UIViewRepresentable {
    
    let view: UIView
    
    func makeUIView(context: Context) -> some UIView { view }
    func updateUIView(_ uiView: UIViewType, context: Context) { }
}

@main
struct PointCloudExampleApp: App {
    @StateObject var arManager = ARManager()
    
    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .bottom) {
                UIViewWrapper(view: arManager.sceneView).ignoresSafeArea()
                
                HStack(spacing: 30) {
                    Button {
                        arManager.isCapturing.toggle()
                    } label: {
                        Image(systemName: arManager.isCapturing ?
                              "stop.circle.fill" :
                                "play.circle.fill")
                    }
                    
                    Button {
                        Task {
                            do {
                                let fileURL = try await PLYFile(pointCloud: arManager.pointCloud).exportToLocalFile()
                                print("PLY file saved at: \(fileURL)")
                                sharePLYFile(url: fileURL)
                            } catch {
                                print("Failed to save PLY file: \(error)")
                            }
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up.circle.fill")
                    }
                }.foregroundStyle(.black, .white)
                    .font(.system(size: 50))
                    .padding(25)
            }
        }
    }
    
    func sharePLYFile(url: URL) {
        let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let topController = UIApplication.shared.windows.first?.rootViewController {
            topController.present(activityViewController, animated: true, completion: nil)
        }
    }
}
