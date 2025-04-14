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

/*
struct Vertex_POS_NRM
{
    let position3d: SIMD3<Float>
    let normal3d: SIMD3<Float>
    
    static func BuildDefaultVertexDescriptor() -> MTLVertexDescriptor {
        let vertexDescriptor = MTLVertexDescriptor()
        
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[0].offset = 0
        
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.attributes[1].offset = MemoryLayout<Vertex_POS_NRM>.offset(of: \.normal3d)!
        
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex_POS_NRM>.stride
        
        return vertexDescriptor
        
        switch iVertLayout {
        case .POSITION_FLOAT3_NORMAL_FLOAT3:
            
            
        case .POSITION_FLOAT3_NORMAL_FLOAT3_TEXCOORD0_FLOAT2:
            
            
        case .POSITION_FLOAT3_NORMAL_FLOAT3_TANGENT_FLOAT3_TEXCOORD0_FLOAT2:
            vertexDescriptor.attributes[0].format = .float3
            vertexDescriptor.attributes[0].bufferIndex = 0
            vertexDescriptor.attributes[0].offset = 0
            
            vertexDescriptor.attributes[1].format = .float3
            vertexDescriptor.attributes[1].bufferIndex = 0
            vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.stride * 3
            
            vertexDescriptor.attributes[2].format = .float3
            vertexDescriptor.attributes[2].bufferIndex = 0
            vertexDescriptor.attributes[2].offset = MemoryLayout<Float>.stride * 6
            
            vertexDescriptor.attributes[3].format = .float2
            vertexDescriptor.attributes[3].bufferIndex = 0
            vertexDescriptor.attributes[3].offset = MemoryLayout<Float>.stride * 9
    }
}

struct Vertex_POS_NRM_TEX
{
    static func BuildDefaultVertexDescriptor() -> MTLVertexDescriptor {
        let vertexDescriptor = MTLVertexDescriptor()
        
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[0].offset = 0
        
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.stride * 3
        
        vertexDescriptor.attributes[2].format = .float2
        vertexDescriptor.attributes[2].bufferIndex = 0
        vertexDescriptor.attributes[2].offset = MemoryLayout<Float>.stride * 6
        
    }
}

struct Vertex_POS_NRM_TAN_TEX
{
    
}

struct VertexBuffer
{
    var m_vertexLayout : VertexBufferLayout
    
    var m_vertexData_POS_NRM : [Vertex_POS_NRM]
    var m_vertexData_POS_NRM_TEX : [Vertex_POS_NRM_TEX]
    var m_vertexData_POS_NRM_TAN_TEX : [Vertex_POS_NRM_TAN_TEX]
}
*/
