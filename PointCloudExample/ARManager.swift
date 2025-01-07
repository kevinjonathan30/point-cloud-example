//
//  ARManager.swift
//  MyPointCloudApp
//
//  Created by Kevin Jonathan on 2025/01/02.
//

import Foundation
import ARKit

actor ARManager: NSObject, ARSessionDelegate, ObservableObject {
    
    @MainActor let sceneView = ARSCNView()
    @MainActor private var isProcessing = false
    @MainActor @Published var isCapturing = false
    @MainActor let geometryNode = SCNNode()
    @MainActor let pointCloud = PointCloud()
    
    @MainActor
    override init() {
        super.init()
        
        sceneView.session.delegate = self
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = .sceneDepth
        sceneView.session.run(configuration)
        sceneView.scene.rootNode.addChildNode(geometryNode)
    }
    
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        Task { await process(frame: frame) }
    }
    
    @MainActor
    private func process(frame: ARFrame) async {
        guard !isProcessing && isCapturing else { return }
        
        isProcessing = true
        await pointCloud.process(frame: frame)
        await updateGeometry()
        isProcessing = false
    }
    
    func updateGeometry() async {
        let vertices = await pointCloud.vertices.values.enumerated().filter { index, _ in
            index % 10 == 9
        }.map { $0.element }
        
        let vertexSource = SCNGeometrySource(vertices: vertices.map { $0.position } )
        
        let colorData = Data(bytes: vertices.map { $0.color },
                             count: MemoryLayout<simd_float4>.size * vertices.count)
        
        let colorSource = SCNGeometrySource(data: colorData,
                                            semantic: .color,
                                            vectorCount: vertices.count,
                                            usesFloatComponents: true,
                                            componentsPerVector: 4,
                                            bytesPerComponent: MemoryLayout<Float>.size,
                                            dataOffset: 0,
                                            dataStride: MemoryLayout<SIMD4<Float>>.size)
        
        let pointIndices: [UInt32] = Array(0..<UInt32(vertices.count))
        let element = SCNGeometryElement(indices: pointIndices, primitiveType: .point)
        
        element.maximumPointScreenSpaceRadius = 15
        
        let geometry = SCNGeometry(sources: [vertexSource, colorSource],
                                   elements: [element])
        geometry.firstMaterial?.isDoubleSided = true
        geometry.firstMaterial?.lightingModel = .constant
        
        Task { @MainActor in
            geometryNode.geometry = geometry
        }
    }
}

struct PLYFile {
    
    let pointCloud: PointCloud
    
    enum Error: LocalizedError {
        case cannotExport
    }
    
    func savePLYFileToDocuments(fileName: String, data: Data) throws -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        try data.write(to: fileURL)
        return fileURL
    }
    
    func exportToLocalFile() async throws -> URL {
        let vertices = await pointCloud.vertices
        
        var plyContent = """
        ply
        format ascii 1.0
        element vertex \(vertices.count)
        property float x
        property float y
        property float z
        property uchar red
        property uchar green
        property uchar blue
        property uchar alpha
        end_header
        """
        
        for vertex in vertices.values {
            let x = vertex.position.x
            let y = vertex.position.y
            let z = vertex.position.z
            let r = UInt8(vertex.color.x * 255)
            let g = UInt8(vertex.color.y * 255)
            let b = UInt8(vertex.color.z * 255)
            let a = UInt8(vertex.color.w * 255)
            
            plyContent += "\n\(x) \(y) \(z) \(r) \(g) \(b) \(a)"
        }
        
        guard let data = plyContent.data(using: .ascii) else {
            throw Error.cannotExport
        }
        
        return try savePLYFileToDocuments(fileName: "exported.ply", data: data)
    }
}
