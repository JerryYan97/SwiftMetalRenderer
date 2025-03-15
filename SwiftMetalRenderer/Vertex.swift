//
//  Vertex.swift
//  SwiftMetalRenderer
//
//  Created by Jiarui Yan on 3/15/25.
//

import MetalKit

struct Vertex{
    let position2d: SIMD2<Float>
    let colorRgb: SIMD3<Float>
    
    static func BuildDefaultVertexDescriptor() -> MTLVertexDescriptor {
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0

        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].offset = MemoryLayout<Vertex>.offset(of: \.colorRgb)!
        vertexDescriptor.attributes[1].bufferIndex = 0

        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        
        return vertexDescriptor
    }
}
