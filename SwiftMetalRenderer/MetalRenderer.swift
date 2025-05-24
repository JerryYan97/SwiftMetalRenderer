//
//  MetalRenderer.swift
//  SwiftMetalRenderer
//
//  Created by Jiarui Yan on 3/15/25.
//


import MetalKit
import simd

struct RenderInfoBuffer
{
    let modelMatrix : simd_float4x4
    let vpMatrix    : simd_float4x4
    let viewMatrix  : simd_float4x4
    let camPos      : simd_float4
}

struct MaterialInfoBuffer
{
    let materialInfoMask : simd_uint4
    
    let baseColorFactor : simd_float4
    let pbrInfoFactor   : simd_float4
    
    let texTransBaseColor : simd_float4
    let texTransMetallicRoughness : simd_float4
    let texTransNormal : simd_float4
    let texTransAO : simd_float4
    let texTransEmissive : simd_float4
}

class MetalRenderer: NSObject, MTKViewDelegate {
    let m_commandQueue: MTLCommandQueue
    let m_device: MTLDevice
    let m_sceneManager: SceneManager
    let m_shaderLibrary: MTLLibrary
    
    private var rotationMatrix = matrix_identity_float4x4
    private var m_tempTransformationMatrix = matrix_identity_float4x4
    private var m_tempAspect : Float = 0.0
    private var m_depthTexture : MTLTexture?
    
    
    
    override init(){
        m_device = MetalRenderer.createDevice()
        m_sceneManager = SceneManager()
        m_commandQueue = MetalRenderer.createCmdQueue(iDevice: m_device)
        m_shaderLibrary = MetalRenderer.createShaderLibrary(iDevice: m_device)
        
        let sceneConfigFile = "DefaultScene.yaml"
        
        let programPath = Bundle.main.bundlePath
        let exePath = Bundle.main.executablePath ?? ""
        let rsrcPath = Bundle.main.resourcePath ?? ""
        print("Program Path: ", programPath, " .Executable Path: ", exePath, "\n")
        
        let fileManager = FileManager.default
        
        do{
            let contents = try fileManager.contentsOfDirectory(atPath: rsrcPath)
            for content in contents{
                print("item: ", content)
            }
        }catch{
            print("Error Checking File System")
        }
        
        m_sceneManager.LoadYamlScene(iDevice: m_device, iSceneFilePath: sceneConfigFile)
        
        super.init()
    }
    
    // The camera viewing direction in the camera space is the negative z axis.
    private func PerspectiveMatrix(perspectiveWithAspect aspect: Float, fovy: Float, near: Float, far: Float) -> simd_float4x4{
        let yy = 1 / tan(fovy * 0.5)
        let xx = yy / aspect
        let zRange = far - near
        let zz = -(far + near) / zRange
        let ww = -2 * far * near / zRange
        
        let perMat : simd_float4x4 = simd_float4x4.init(
            [xx,  0,  0,  0],
            [ 0, yy,  0,  0],
            [ 0,  0, zz, -1],
            [ 0,  0, ww,  0]
        )
        
        return perMat
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    func GenVertDescriptor(iVertLayout: VertexBufferLayout) -> MTLVertexDescriptor {
        let vertexDescriptor = MTLVertexDescriptor()
        
        switch iVertLayout {
        case .POSITION_FLOAT3_NORMAL_FLOAT3_COLOR_FLOAT4:
            vertexDescriptor.attributes[0].format = .float3
            vertexDescriptor.attributes[0].bufferIndex = 0
            vertexDescriptor.attributes[0].offset = 0
            
            vertexDescriptor.attributes[1].format = .float3
            vertexDescriptor.attributes[1].bufferIndex = 0
            vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.stride * 3
            
            vertexDescriptor.attributes[2].format = .float4
            vertexDescriptor.attributes[2].bufferIndex = 0
            vertexDescriptor.attributes[2].offset = MemoryLayout<Float>.stride * 6
            
            vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.stride * 10
            
        case .POSITION_FLOAT3_NORMAL_FLOAT3_COLOR_FLOAT4_TEXCOORD0_FLOAT2:
            vertexDescriptor.attributes[0].format = .float3
            vertexDescriptor.attributes[0].bufferIndex = 0
            vertexDescriptor.attributes[0].offset = 0
            
            vertexDescriptor.attributes[1].format = .float3
            vertexDescriptor.attributes[1].bufferIndex = 0
            vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.stride * 3
            
            vertexDescriptor.attributes[2].format = .float4
            vertexDescriptor.attributes[2].bufferIndex = 0
            vertexDescriptor.attributes[2].offset = MemoryLayout<Float>.stride * 6
            
            vertexDescriptor.attributes[3].format = .float2
            vertexDescriptor.attributes[3].bufferIndex = 0
            vertexDescriptor.attributes[3].offset = MemoryLayout<Float>.stride * 10
            
            vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.stride * 12
            
        case .POSITION_FLOAT3_NORMAL_FLOAT3_COLOR_FLOAT4_TANGENT_FLOAT3_TEXCOORD0_FLOAT2:
            vertexDescriptor.attributes[0].format = .float3
            vertexDescriptor.attributes[0].bufferIndex = 0
            vertexDescriptor.attributes[0].offset = 0
            
            vertexDescriptor.attributes[1].format = .float3
            vertexDescriptor.attributes[1].bufferIndex = 0
            vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.stride * 3
            
            vertexDescriptor.attributes[2].format = .float4
            vertexDescriptor.attributes[2].bufferIndex = 0
            vertexDescriptor.attributes[2].offset = MemoryLayout<Float>.stride * 6
            
            vertexDescriptor.attributes[3].format = .float3
            vertexDescriptor.attributes[3].bufferIndex = 0
            vertexDescriptor.attributes[3].offset = MemoryLayout<Float>.stride * 10
            
            vertexDescriptor.attributes[4].format = .float2
            vertexDescriptor.attributes[4].bufferIndex = 0
            vertexDescriptor.attributes[4].offset = MemoryLayout<Float>.stride * 13
            
            vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.stride * 15
            
        default:
            fatalError("Unsupported vertex layout.")
        }
        
        return vertexDescriptor
    }
    
    func RenderStaticModelNode(iStaticModelNode: StaticModel, iRenderCmdEncoder: MTLRenderCommandEncoder){
        /// Generate per scene information
        var materialInfoMask: simd_uint4 = simd_uint4(0, 0, 0, 0)
        
        iStaticModelNode.m_primitiveShapes.forEach { (iPrimitiveShape) in
            let library = MetalRenderer.createShaderLibrary(iDevice: m_device)
            var vertexDescriptor = GenVertDescriptor(iVertLayout: iPrimitiveShape.m_vertexLayout!)
            var fragmentFunction = library.makeFunction(name: "fragment_main")
            var vertexFunction: MTLFunction
            
            switch iPrimitiveShape.m_vertexLayout {
            case .POSITION_FLOAT3_NORMAL_FLOAT3_COLOR_FLOAT4:
                if let tmpVertFunc = library.makeFunction(name: "vertex_main_POS_NRM") {
                    vertexFunction = tmpVertFunc
                } else {
                    fatalError("Could not find vert func for POS_NRM.")
                }
                
            case .POSITION_FLOAT3_NORMAL_FLOAT3_COLOR_FLOAT4_TEXCOORD0_FLOAT2:
                if let tmpVertFunc = library.makeFunction(name: "vertex_main_POS_NRM_UV") {
                    vertexFunction = tmpVertFunc
                } else {
                    fatalError("Could not find vert func for POS_NRM_UV.")
                }
                
            case .POSITION_FLOAT3_NORMAL_FLOAT3_COLOR_FLOAT4_TANGENT_FLOAT3_TEXCOORD0_FLOAT2:
                if let tmpVertFunc = library.makeFunction(name: "vertex_main_POS_NRM_TAN_UV") {
                    vertexFunction = tmpVertFunc
                } else {
                    fatalError("Could not find vert func for vertex_main_POS_NRM_TAN_UV.")
                }
            default:
                fatalError("Invalid vertex layout.")
            }
            
            ///
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.vertexDescriptor = vertexDescriptor
            
            let pipelineState = MetalRenderer.createPipelineState(iDevice: m_device, descriptor: pipelineDescriptor)
            ///
            
            ///
            let depthStencilDescriptor = MTLDepthStencilDescriptor()
            depthStencilDescriptor.label = "DepthStencilState"
            depthStencilDescriptor.depthCompareFunction = .less
            depthStencilDescriptor.isDepthWriteEnabled = true
            
            let depthStencilState = m_device.makeDepthStencilState(descriptor: depthStencilDescriptor)!
            ///
            
            m_tempTransformationMatrix = matrix_identity_float4x4
            m_tempTransformationMatrix.columns.3 = simd_float4(1.0, -1.0, -5.0, 1.0)
            let tmpRotationMatrix = float4x4(rotationY: Float.pi/4)
            m_tempTransformationMatrix = m_tempTransformationMatrix * tmpRotationMatrix
            
            let perspectiveMat = PerspectiveMatrix(perspectiveWithAspect: m_tempAspect, fovy: Float.pi/5, near: 0.1, far: 1000.0)
            let viewMat = m_sceneManager.m_activeCamera?.GetViewMatrix() ?? matrix_identity_float4x4
            let camPos: simd_float4 = simd_float4(m_sceneManager.m_activeCamera!.m_worldPos, 0.0)
            
            /// Materials populating
            let baseColorFactorFltArray = iPrimitiveShape.m_material!.m_baseColorFactor!
            let baseColorFactor : simd_float4 = simd_float4(baseColorFactorFltArray[0],
                                                            baseColorFactorFltArray[1],
                                                            baseColorFactorFltArray[2],
                                                            baseColorFactorFltArray[3])
            
            var materialInfoMask_x : UInt32 = 0
            if iPrimitiveShape.m_material!.m_baseColorTexture == nil {
                materialInfoMask_x |= 0x01
            }
            
            let pbrInfo : simd_float4 = simd_float4(iPrimitiveShape.m_material!.m_metallicFactor!,
                                                    iPrimitiveShape.m_material!.m_roughnessFactor!,
                                                    0.0, 0.0)
            
            if iPrimitiveShape.m_material!.m_metallicRoughnessTexture == nil {
                materialInfoMask_x |= 0x02
            }
            
            if iPrimitiveShape.m_material!.m_normalMapTexture != nil {
                materialInfoMask_x |= 0x04
            }
            
            if iPrimitiveShape.m_material!.m_aoMapTexture != nil {
                materialInfoMask_x |= 0x08
            }
            
            if iPrimitiveShape.m_material!.m_emissveTexture != nil {
                /// Indicate that we use an emissive texture
                materialInfoMask_x |= 0x10
            }
            ///
            
            materialInfoMask.x = materialInfoMask_x
            
            var renderInfo : RenderInfoBuffer = RenderInfoBuffer(modelMatrix: iStaticModelNode.m_modelMatrix,
                                                                 vpMatrix: perspectiveMat,
                                                                 viewMatrix: viewMat,
                                                                 camPos: camPos)
            
            var materialInfo : MaterialInfoBuffer = MaterialInfoBuffer(materialInfoMask: materialInfoMask,
                                                                       baseColorFactor: baseColorFactor,
                                                                       pbrInfoFactor: pbrInfo,
                                                                       texTransBaseColor: iPrimitiveShape.m_material!.m_baseColorTexTrans,
                                                                       texTransMetallicRoughness: iPrimitiveShape.m_material!.m_metallicRoughnessTexTrans,
                                                                       texTransNormal: iPrimitiveShape.m_material!.m_normalMapTexTrans,
                                                                       texTransAO: iPrimitiveShape.m_material!.m_aoMapTexTrans,
                                                                       texTransEmissive: iPrimitiveShape.m_material!.m_emissveTexTrans)
            
            iRenderCmdEncoder.setRenderPipelineState(pipelineState)
            iRenderCmdEncoder.setDepthStencilState(depthStencilState)
            iRenderCmdEncoder.setVertexBuffer(iPrimitiveShape.m_vertBufferMtl, offset: 0, index: 0)
            
            iRenderCmdEncoder.setVertexBytes(&renderInfo,
                                             length: MemoryLayout<RenderInfoBuffer>.stride,
                                             index: 1)
            
            iRenderCmdEncoder.setFragmentBytes(&materialInfo,
                                               length: MemoryLayout<MaterialInfoBuffer>.stride,
                                               index: 1)
            
            iRenderCmdEncoder.setFragmentBytes(&renderInfo,
                                               length: MemoryLayout<RenderInfoBuffer>.stride,
                                               index: 2)
            
            iRenderCmdEncoder.setFragmentTexture(iPrimitiveShape.m_material!.m_baseColorTexture, index: 1)
            iRenderCmdEncoder.setFragmentSamplerState(iPrimitiveShape.m_material!.m_baseColorTexSampler, index: 1)
            
            iRenderCmdEncoder.setFragmentTexture(iPrimitiveShape.m_material!.m_normalMapTexture, index: 2)
            iRenderCmdEncoder.setFragmentSamplerState(iPrimitiveShape.m_material!.m_normalMapSampler, index: 2)
            
            iRenderCmdEncoder.setFragmentTexture(iPrimitiveShape.m_material!.m_metallicRoughnessTexture, index: 3)
            iRenderCmdEncoder.setFragmentSamplerState(iPrimitiveShape.m_material!.m_metallicRoughnessTexSampler, index: 3)
            
            iRenderCmdEncoder.setFragmentTexture(iPrimitiveShape.m_material!.m_aoMapTexture, index: 4)
            iRenderCmdEncoder.setFragmentSamplerState(iPrimitiveShape.m_material!.m_aoMapSampler, index: 4)
            
            iRenderCmdEncoder.setFragmentTexture(iPrimitiveShape.m_material!.m_emissveTexture, index: 5)
            iRenderCmdEncoder.setFragmentSamplerState(iPrimitiveShape.m_material!.m_emissveTexSampler, index: 5)
            
            iRenderCmdEncoder.drawIndexedPrimitives(type: .triangle,
                                                    indexCount: iPrimitiveShape.m_idxCnt!,
                                                    indexType: iPrimitiveShape.m_idxType!,
                                                    indexBuffer: iPrimitiveShape.m_idxBufferMtl!,
                                                    indexBufferOffset: 0)
        }
    }
    
    private func CreateDepthFunc(_ width: Int, _ height: Int) {
        var depthTexDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .depth32Float, width: width, height: height, mipmapped: false
        )
        depthTexDescriptor.usage = .renderTarget
        depthTexDescriptor.storageMode = .private
        
        m_depthTexture = m_device.makeTexture(descriptor: depthTexDescriptor)
        m_depthTexture?.label = "Depth Render Target"
    }
    
    func draw(in view: MTKView) {
        if m_sceneManager.IsAssetReady() {
            if let drawable = view.currentDrawable,
               var renderPassDescriptor = view.currentRenderPassDescriptor {
                /// Pre-Render Stage
                /// Resize depth texture if it's needed or the first time
                if m_depthTexture == nil {
                    CreateDepthFunc(drawable.texture.width, drawable.texture.height)
                } else if m_depthTexture!.width != drawable.texture.width ||
                          m_depthTexture!.height != drawable.texture.height {
                    CreateDepthFunc(drawable.texture.width, drawable.texture.height)
                }
                
                /// Update shapes' model matrices (We will directly use 'setVertexBytes' to upload uniform buffers)
                renderPassDescriptor.colorAttachments[0].loadAction = .clear
                renderPassDescriptor.colorAttachments[0].storeAction = .store
                renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.529, green: 0.81, blue: 0.92, alpha: 1.0)
                renderPassDescriptor.depthAttachment.texture = m_depthTexture
                renderPassDescriptor.depthAttachment.clearDepth = 1.0
                renderPassDescriptor.depthAttachment.loadAction = .clear
                renderPassDescriptor.depthAttachment.storeAction = .dontCare
                
                m_tempAspect = Float(drawable.texture.width) / Float(drawable.texture.height)
                
                guard let commandBuffer = m_commandQueue.makeCommandBuffer(),
                      let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
                    fatalError("Could not set up objects for render encoding")
                }
                
                /// Pre-render prepare
                
                
                /// Opaque Rendering Pass
                ///
                for i in 0..<m_sceneManager.m_sceneGraph.m_nodes.count {
                    let sceneNode = m_sceneManager.m_sceneGraph.m_nodes[i]
                    if let staticModelNode = sceneNode as? StaticModel {
                        RenderStaticModelNode(iStaticModelNode: staticModelNode, iRenderCmdEncoder: renderEncoder)
                    }
                }
                ///
                
                renderEncoder.endEncoding()
                
                commandBuffer.present(drawable)
                commandBuffer.commit()
            }
        }
    }
    
    func updateCamera(verticalRotation: Float, horizontalRotation: Float, distance: Float) {
        if m_sceneManager.m_activeCamera != nil {
            /// Horizontal from positive-x to positive-z
            let xVal = sin(horizontalRotation)
            let zVal = -cos(horizontalRotation)
            let yVal = sin(verticalRotation)
            
            let camDir : simd_float3 = normalize(simd_float3(xVal, yVal, zVal))
            m_sceneManager.m_activeCamera!.m_worldPos = distance * camDir
        }
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
