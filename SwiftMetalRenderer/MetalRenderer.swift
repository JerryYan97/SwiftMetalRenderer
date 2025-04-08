//
//  MetalRenderer.swift
//  SwiftMetalRenderer
//
//  Created by Jiarui Yan on 3/15/25.
//


import MetalKit

class MetalRenderer: NSObject, MTKViewDelegate {
    let vertexBuffer: MTLBuffer
    // let idxBuffer: MTLBuffer
    let pipelineState: MTLRenderPipelineState
    let commandQueue: MTLCommandQueue
    let device: MTLDevice
    let m_sceneManager: SceneManager
    
    /*
    let vertices: [Vertex] = [
        Vertex(position2d: [-1, 1], colorRgb: [0, 0, 1]),
        Vertex(position2d: [-1, -1], colorRgb: [1, 1, 1]),
        Vertex(position2d: [1, -1], colorRgb: [1, 0, 0]),
        Vertex(position2d: [1, 1], colorRgb: [0, 0, 0])]

    let indices: [UInt16] = [
        0, 1, 2,
        3, 0, 2]
    */
    let vertices: [Vertex] = [
        Vertex(position2d: [0, 1], colorRgb: [0, 0, 1]),
        Vertex(position2d: [-1, -1], colorRgb: [1, 1, 1]),
        Vertex(position2d: [1, -1], colorRgb: [1, 0, 0])]
    
    private var rotationMatrix = matrix_identity_float4x4
    
    override init(){
        device = MetalRenderer.createDevice()
        m_sceneManager = SceneManager()
        commandQueue = MetalRenderer.createCmdQueue(iDevice: device)
        vertexBuffer = MetalRenderer.createGpuBuffer(iDevice: device,
                                                     bufferData: vertices,
                                                     lenBytes: MemoryLayout<Vertex>.stride * vertices.count)
        /*
        idxBuffer = MetalRenderer.createGpuBuffer(iDevice: device,
                                                  bufferData: indices,
                                                  lenBytes: MemoryLayout<UInt16>.stride * indices.count)
        */
        
        let library = MetalRenderer.createShaderLibrary(iDevice: device)
        let vertexFunction = library.makeFunction(name: "vertex_main")
        let fragmentFunction = library.makeFunction(name: "fragment_main")
        let vertexDescriptor = MetalRenderer.buildDefaultVertexDescriptor()

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineState = MetalRenderer.createPipelineState(iDevice: device, descriptor: pipelineDescriptor)
        
        let sceneConfigFile = "/Users/jiaruiyan/Projects/SwiftMetalRenderer/SwiftMetalRenderer/scene/CubeScene.yaml"
        m_sceneManager.LoadYamlScene(iDevice: device, iSceneFilePath: sceneConfigFile)
        
        super.init()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    func draw(in view: MTKView) {
        if m_sceneManager.IsAssetReady() {
            
        }
        
        
        if let drawable = view.currentDrawable,
           let renderPassDescriptor = view.currentRenderPassDescriptor {
            
            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
                fatalError("Could not set up objects for render encoding")
            }
            
            renderEncoder.setRenderPipelineState(pipelineState)
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBytes(&rotationMatrix, length: MemoryLayout<simd_float4x4>.stride, index: 1)
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            renderEncoder.endEncoding()
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
    
    func updateRotation(angle: Float) {
        rotationMatrix = float4x4(rotationZ: angle)
    }
    
    private static func createDevice() -> MTLDevice {
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            fatalError("GPU not available")
        }
        return defaultDevice
    }
    
    private static func createCmdQueue(iDevice: MTLDevice) -> MTLCommandQueue {
        guard let defaultCommandQueue = iDevice.makeCommandQueue() else {
            fatalError("Could not create a command queue.")
        }
        return defaultCommandQueue
    }
    
    private static func createGpuBuffer(iDevice: MTLDevice, bufferData: UnsafeRawPointer, lenBytes: Int) -> MTLBuffer {
        guard let gpuBuffer = iDevice.makeBuffer(bytes: bufferData, length: lenBytes, options: []) else {
            fatalError("Could not create the GPU buffer.")
        }
        return gpuBuffer
    }
    
    private static func createShaderLibrary(iDevice: MTLDevice) -> MTLLibrary {
        guard let library = iDevice.makeDefaultLibrary() else {
            fatalError("Could not create the shader library.")
        }
        return library
    }
    
    private static func buildDefaultVertexDescriptor() -> MTLVertexDescriptor {
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
    
    private static func createPipelineState(iDevice: MTLDevice, descriptor: MTLRenderPipelineDescriptor) -> MTLRenderPipelineState {
        guard let pipelineState = try? iDevice.makeRenderPipelineState(descriptor: descriptor) else {
            fatalError("Could not create the pipeline state")
        }
        return pipelineState
    }
}
