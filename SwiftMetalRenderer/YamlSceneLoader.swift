//
//  YamlSceneLoader.swift
//  SwiftMetalRenderer
//
//  Created by Jiarui Yan on 3/16/25.
//

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

import Foundation
import Yams
import GLTFKit2
import MetalKit

enum SceneObjectType {
    case StaticModel
    case Camera
}

enum VertexBufferLayout
{
    case POSITION_FLOAT3_NORMAL_FLOAT3_COLOR_FLOAT4_TANGENT_FLOAT3_TEXCOORD0_FLOAT2
    case POSITION_FLOAT3_NORMAL_FLOAT3_COLOR_FLOAT4_TEXCOORD0_FLOAT2
    case POSITION_FLOAT3_NORMAL_FLOAT3_COLOR_FLOAT4
}

func ChooseVertexBufferLayout(hasTangent: Bool, hasTexCoord: Bool) -> VertexBufferLayout{
    var res: VertexBufferLayout = .POSITION_FLOAT3_NORMAL_FLOAT3_COLOR_FLOAT4
    if hasTangent {
        res = .POSITION_FLOAT3_NORMAL_FLOAT3_COLOR_FLOAT4_TANGENT_FLOAT3_TEXCOORD0_FLOAT2
    } else {
        if hasTexCoord {
            res = .POSITION_FLOAT3_NORMAL_FLOAT3_COLOR_FLOAT4_TEXCOORD0_FLOAT2
        }
    }
    
    return res
}

func VertexBufferLayoutAttributeCount(iLayout: VertexBufferLayout) -> Int {
    switch iLayout {
    case .POSITION_FLOAT3_NORMAL_FLOAT3_COLOR_FLOAT4:
        return 3
    case .POSITION_FLOAT3_NORMAL_FLOAT3_COLOR_FLOAT4_TANGENT_FLOAT3_TEXCOORD0_FLOAT2:
        return 5
    case .POSITION_FLOAT3_NORMAL_FLOAT3_COLOR_FLOAT4_TEXCOORD0_FLOAT2:
        return 4
    @unknown default:
        fatalError("Unhandled vertex buffer layout")
    }
}

struct YamlSceneObjStruct: Codable {
    var objName: String
    var objType: String
    var translation: [Float]?
    var modelPath: String?
    var rotation: [Float]?
    var fov: Float?
    var farPlane: Float?
    var nearPlane: Float?
    var gltfLoadType: String?
}

struct YamlSceneInfoStruct: Codable{
    var sceneName: String
    var version: Int?
    var sceneObjs: [String : YamlSceneObjStruct]? // Scene object name : Scene object
}

class SceneNode
{
    let m_objType: SceneObjectType?
    let m_objName: String?
    
    init(iObjType: SceneObjectType?, iObjName: String?){
        m_objType = iObjType
        m_objName = iObjName
    }
}

enum MaterialType
{
    case None
    case Constant
}

class Material
{
    var m_baseColorFactor: [Float]?
    var m_metallicFactor: Float?
    var m_roughnessFactor: Float?
    
    var m_baseColorTexture: MTLTexture?
    var m_baseColorTexSampler: MTLSamplerState?
    var m_baseColorTexTrans: simd_float4 = simd_float4(1, 1, 0, 0)
    
    var m_normalMapTexture: MTLTexture?
    var m_normalMapSampler: MTLSamplerState?
    var m_normalMapTexTrans: simd_float4 = simd_float4(1, 1, 0, 0)
    
    var m_metallicRoughnessTexture: MTLTexture?
    var m_metallicRoughnessTexSampler: MTLSamplerState?
    var m_metallicRoughnessTexTrans: simd_float4 = simd_float4(1, 1, 0, 0)
    
    var m_aoMapTexture: MTLTexture?
    var m_aoMapSampler: MTLSamplerState?
    var m_aoMapTexTrans: simd_float4 = simd_float4(1, 1, 0, 0)
    
    var m_emissveTexture: MTLTexture?
    var m_emissveTexSampler: MTLSamplerState?
    var m_emissveTexTrans: simd_float4 = simd_float4(1, 1, 0, 0)
}

struct BoundingBox {
    let min: SIMD3<Float>
    let max: SIMD3<Float>
}

struct PrimitiveShape {
    var m_vertexLayout: VertexBufferLayout?
    var m_vertexData: UnsafeMutableRawBufferPointer?
    
    var m_idxType: MTLIndexType?
    var m_idxData: UnsafeMutableRawBufferPointer?
    var m_idxCnt: Int?
    
    var m_material: Material?
    
    var m_vertBufferMtl: MTLBuffer?
    var m_idxBufferMtl: MTLBuffer?
    
    var m_bbx: BoundingBox?
}

class StaticModel : SceneNode {
    var m_primitiveShapes: [PrimitiveShape] = []
    var m_modelMatrix: simd_float4x4 = simd_float4x4()
    // var m_worldMatrix: [Float] = []
    
}

class Camera : SceneNode {
    var m_worldMatrix: [Float] = []
    var m_fov: Float = 0.0
    var m_aspectRatio: Float = 0.0
    
    var m_worldPos: simd_float3 = simd_float3()
    var m_lookAt: simd_float3 = simd_float3()
    
    /// This position depends on scene. The first auto-gen camera position to get a good view.
    var m_defaultWorldPos: simd_float3 = simd_float3(0.0, 0.0, -5.0)
    
    let m_worldUp: simd_float3 = simd_float3(0.0, 1.0, 0.0)
    
    
    func GetViewMatrix() -> simd_float4x4 {
        let viewNrm = normalize(m_lookAt - m_worldPos)
        let right = cross(viewNrm, m_worldUp)
        let rightNrm = normalize(right)
        let up = cross(rightNrm, viewNrm)
        let upNrm = normalize(up)
        
        let camSpacePositiveZ = -viewNrm
        
        let e03: Float = -dot(m_worldPos, rightNrm)
        let e13: Float = -dot(m_worldPos, upNrm)
        let e23: Float = -dot(m_worldPos, camSpacePositiveZ)
        
        let viewMat : simd_float4x4 = simd_float4x4.init(
            [rightNrm.x, upNrm.x, camSpacePositiveZ.x, 0.0],
            [rightNrm.y, upNrm.y, camSpacePositiveZ.y, 0.0],
            [rightNrm.z, upNrm.z, camSpacePositiveZ.z, 0.0],
            [e03,        e13,     e23,       1.0])
        
        return viewMat
    }
}

struct SceneGraph {
    var m_nodes: [SceneNode]
}

struct YamlSceneLoader {
    
}

func GetAComponentEleBytesCnt(componentType : GLTFComponentType) -> Int {
    var bytesCnt : Int = 0
    
    switch componentType {
    case .float:
        bytesCnt = 4
    case .unsignedInt:
        bytesCnt = 4
    case .unsignedShort:
        bytesCnt = 2
    case .short:
        bytesCnt = 2
    case .unsignedByte:
        bytesCnt = 1
    case .byte:
        bytesCnt = 1
    default:
        assert(false)
    }
    
    return bytesCnt
}

func GetComponentEleCnt(valDimension : GLTFValueDimension) -> Int {
    var componentDim : Int = 0
    
    switch valDimension {
    case .scalar:
        componentDim = 1
    case .vector2:
        componentDim = 2
    case .vector3:
        componentDim = 3
    case .vector4:
        componentDim = 4
    case .matrix2:
        componentDim = 4
    case .matrix3:
        componentDim = 9
    case .matrix4:
        componentDim = 16
    default:
        assert(false)
    }
    
    return componentDim
}

class SceneManager
{
    var m_curSceneInfo: YamlSceneInfoStruct
    let m_assetPath: String
    let m_scenePath: String
    
    var m_mtlDevice: MTLDevice?
    
    var m_sceneGraph: SceneGraph
    
    var m_activeCamera: Camera?
    
    var m_asset: GLTFAsset? {
        didSet{
            if m_asset != nil {
                /// Parsing the gltf asset
                print("Intercept m_asset")
                let assetRef = m_asset!
                
                ///
                for nodeIdx in 0..<assetRef.nodes.count {
                    // let meshRef = assetRef.meshes[meshIdx]
                    let nodeRef = assetRef.nodes[nodeIdx]
                    
                    if nodeRef.mesh == nil {
                        continue
                    }
                    
                    assert(nodeRef.mesh != nil, "Node Mesh cannot be nil!")
                    let meshRef = nodeRef.mesh!
                    
                    let staticModelNode: StaticModel = StaticModel(iObjType: Optional.none, iObjName: Optional.none)
                    staticModelNode.m_modelMatrix = nodeRef.matrix
                    
                    // Currently only support a single mesh:
                    for primitiveIdx in 0..<meshRef.primitives.count {
                        
#if DEBUG
                        print("<YamlSceneLoader>: prim ", primitiveIdx, ":")
#endif
                        
                        let prim = meshRef.primitives[primitiveIdx]
                        let posAttribute = prim.attribute(forName: "POSITION")
                        let nrmAttribute = prim.attribute(forName: "NORMAL")
                        let tanAttribute = prim.attribute(forName: "TANGENT")
                        let uvAttribute = prim.attribute(forName: "TEXCOORD_0")
                        let colorAttribute = prim.attribute(forName: "COLOR_0")
                        
                        assert(posAttribute != nil, "A primitive must have a POSITION attribute")
                        assert(posAttribute!.accessor.componentType == .float, "POSITION attribute must be float components")
                        assert(posAttribute!.accessor.dimension == .vector3, "POSITION attribute must be 3D vector")
                        assert(prim.indices != nil, "A primitive must have an index buffer")
                        
                        /// Load Position
                        let pPosData = ReadOutAccessorData(iAccessor: posAttribute!.accessor)
                        
                        /// Load Normal
                        let pNormalData = ReadOutAccessorData(iAccessor: nrmAttribute!.accessor)
                        
                        /// Load Tangent
                        var pTangentData : UnsafeMutableRawBufferPointer?
                        if(tanAttribute != nil){
                            pTangentData = ReadOutAccessorData(iAccessor: tanAttribute!.accessor)
                        }
                        
                        var pUVData : UnsafeMutableRawBufferPointer?
                        if(uvAttribute != nil){
                            pUVData = ReadOutAccessorData(iAccessor: uvAttribute!.accessor)
                            assert(uvAttribute!.accessor.componentType == .float, "Currently only support float uv.")
                        }
                        
                        var pColorData : UnsafeMutableRawBufferPointer? = nil
                        var colorComponentCnt : Int = 0
                        if(colorAttribute != nil){
                            pColorData = ReadOutAccessorData(iAccessor: colorAttribute!.accessor)
                            colorComponentCnt = GetComponentEleCnt(valDimension: colorAttribute!.accessor.dimension)
                            assert(colorAttribute!.accessor.componentType == .float, "Currently only support float color.")
                        }
                        
                        /// Construct the vertex buffer and index buffer
                        var primShape: PrimitiveShape = PrimitiveShape()
                        let vertLayout = ChooseVertexBufferLayout(hasTangent: tanAttribute != nil,
                                                                  hasTexCoord: uvAttribute != nil)
                        primShape.m_vertexLayout = vertLayout
                        primShape.m_idxData = ReadOutAccessorData(iAccessor: prim.indices!)
                        primShape.m_idxType = IsIdxTypeUint32(iIdxAccessor: prim.indices!)
                        primShape.m_idxCnt = prim.indices!.count
                        (primShape.m_vertexData, primShape.m_bbx) = AssembleVertexBuffer(iPos: pPosData,
                                                                                         iNrm: pNormalData,
                                                                                         iTangent: pTangentData,
                                                                                         iUV: pUVData,
                                                                                         iColor: (pColorData, colorComponentCnt),
                                                                                         iVertSizeInBytes: VertSizeInByte(iVertLayout: vertLayout))
                        
                        /// Load Material
                        assert(prim.material != nil, "Cannot find the material.")
                        assert(prim.material!.metallicRoughness != nil, "Cannot find the metallicRoughness.")
                        
                        let primMaterial = prim.material!
                        let baseColorFactor = primMaterial.metallicRoughness!.baseColorFactor
                        let baseColorTex = primMaterial.metallicRoughness!.baseColorTexture
                        let metallicFactor = primMaterial.metallicRoughness!.metallicFactor
                        let roughnessFactor = primMaterial.metallicRoughness!.roughnessFactor
                        let metallicRoughnessTex = primMaterial.metallicRoughness!.metallicRoughnessTexture
                        let emissiveTex = primMaterial.emissive!.emissiveTexture
                        
                        var shapeMaterial : Material = Material()
                        
                        let samplerDefaultDesc : MTLSamplerDescriptor = MTLSamplerDescriptor()
                        shapeMaterial.m_normalMapSampler = m_mtlDevice!.makeSamplerState(descriptor: samplerDefaultDesc)
                        shapeMaterial.m_metallicRoughnessTexSampler = m_mtlDevice!.makeSamplerState(descriptor: samplerDefaultDesc)
                        shapeMaterial.m_aoMapSampler = m_mtlDevice!.makeSamplerState(descriptor: samplerDefaultDesc)
                        
                        // NSImage
                        if baseColorTex != nil{
                            shapeMaterial.m_baseColorTexSampler = CreateSampler(gltfSampler: baseColorTex!.texture.sampler!)
                            shapeMaterial.m_baseColorTexture = LoadImageToGPU(gltfTex: baseColorTex!)
                            shapeMaterial.m_baseColorTexTrans = LoadTexTrans(gltfTex: baseColorTex!)
                        } else {
                            let baseColorFactor : [Float] = [baseColorFactor.x,
                                                             baseColorFactor.y,
                                                             baseColorFactor.z,
                                                             baseColorFactor.w]
                            
                            shapeMaterial.m_baseColorFactor = baseColorFactor
                            shapeMaterial.m_baseColorTexSampler = m_mtlDevice!.makeSamplerState(descriptor: samplerDefaultDesc)
                        }
                        
                        if metallicRoughnessTex != nil{
                            shapeMaterial.m_metallicRoughnessTexture = LoadImageToGPU(gltfTex: metallicRoughnessTex!)
                            shapeMaterial.m_metallicRoughnessTexSampler = CreateSampler(gltfSampler: metallicRoughnessTex!.texture.sampler!)
                            shapeMaterial.m_metallicRoughnessTexTrans = LoadTexTrans(gltfTex: metallicRoughnessTex!)
                        } else {
                            let metallicFactor : Float = primMaterial.metallicRoughness!.metallicFactor
                            let roughnessFactor : Float = primMaterial.metallicRoughness!.roughnessFactor
                            
                            shapeMaterial.m_roughnessFactor = roughnessFactor
                            shapeMaterial.m_metallicFactor = metallicFactor
                        }
                        
                        if emissiveTex != nil{
                            shapeMaterial.m_emissveTexture = LoadImageToGPU(gltfTex: emissiveTex!)
                            shapeMaterial.m_emissveTexSampler = CreateSampler(gltfSampler: emissiveTex!.texture.sampler!)
                            shapeMaterial.m_emissveTexTrans = LoadTexTrans(gltfTex: emissiveTex!)
                        }
                        else
                        {
                            shapeMaterial.m_emissveTexSampler = m_mtlDevice!.makeSamplerState(descriptor: samplerDefaultDesc)
                        }
                        
                        primShape.m_material = shapeMaterial
                        
                        staticModelNode.m_primitiveShapes.append(primShape)
                    }
                    m_sceneGraph.m_nodes.append(staticModelNode)
                }
                
                /// Post loading activities
                m_activeCamera = Camera(iObjType: .Camera, iObjName: "MyCamera")
                m_activeCamera!.m_worldPos = simd_float3(0.0, 0.0, -5.0)
                m_activeCamera!.m_defaultWorldPos = simd_float3(0.0, 0.0, -5.0)
                m_activeCamera!.m_lookAt = simd_float3(0.0, 0.0, 0.0)
                m_sceneGraph.m_nodes.append(m_activeCamera!)
            }
        }
    }
    
    init(){
        m_sceneGraph = SceneGraph(m_nodes: [])
        m_curSceneInfo = YamlSceneInfoStruct(sceneName: "", version: nil, sceneObjs: nil)
        
        let fileManager = FileManager.default
        let programPath = Bundle.main.bundlePath
        let execPath = Bundle.main.executablePath
        let rsrcPath = Bundle.main.resourcePath
        print("rsrc path: ", rsrcPath, " .exe path: ", execPath)
        m_assetPath = rsrcPath! + "/assets"
        m_scenePath = rsrcPath! + "/scene"
    }
    
    func IsAssetReady() -> Bool{
        return m_asset != nil
    }
    
    private func LoadTexTrans(gltfTex: GLTFTextureParams) -> simd_float4
    {
        if gltfTex.transform == nil{
            return simd_float4(1.0, 1.0, 0.0, 0.0)
        }else{
            print("scale: \(String(describing: gltfTex.transform!.scale)), offset: \(String(describing: gltfTex.transform!.offset))")
            return simd_float4.init(lowHalf: gltfTex.transform!.scale, highHalf: gltfTex.transform!.offset)
        }
    }
    
    private func LoadImageToGPU(gltfTex: GLTFTextureParams) -> MTLTexture {
        #if os(iOS)
        let tmpCiImage = CIImage(contentsOf: gltfTex.texture.source!.uri!)!
        
        let ciImgExt = tmpCiImage.extent
        let ciColSpaceName = tmpCiImage.colorSpace!.name! as String
        let ciColorSpace = tmpCiImage.colorSpace!
        
        print("Color Space: \(ciColSpaceName)", ", Extent: \(ciImgExt)", ", Num Component: \(ciColorSpace.numberOfComponents)")
        
        let context = CIContext(options: nil)
        let cgSPLinear = CGColorSpace(name: CGColorSpace.genericRGBLinear)
        let cgImage = context.createCGImage(tmpCiImage, from: ciImgExt, format: .RGBA8, colorSpace: cgSPLinear)
        
        print("CG Image -- Width: \(cgImage!.width), Height: \(cgImage!.height), Bits Per Component: \(cgImage!.bitsPerComponent), Bits Per Pixel: \(cgImage!.bitsPerPixel), Bytes Per Row: \(cgImage!.bytesPerRow), Color Space: \(String(describing: cgImage!.colorSpace)), pixel format: \(String(describing: cgImage!.pixelFormatInfo)), Component Count: \(cgImage!.colorSpace!.numberOfComponents), Alpha Info: \(String(describing: cgImage!.alphaInfo))")
        
        let dataPtr = CFDataGetBytePtr(cgImage?.dataProvider?.data)
        
        let pixWidth : Int = cgImage?.width ?? 0
        let pixHeight : Int = cgImage?.height ?? 0
        
        assert(cgImage != nil, "Faid to load image.")
        #elseif os(macOS)
        var loadImg = NSImage(contentsOf: gltfTex.texture.source!.uri!)
        // let imageNSData = NSData(contentsOf: gltfTex.texture.source!.uri!)
        // let imageData = Data(referencing: imageNSData!)
        assert(loadImg != nil, "Faid to load image.")
        assert(loadImg!.representations.isEmpty == false, "Failed to load image.")
        #endif
        
        var pixelData : [Float] = []
        
        #if os(iOS)
        // TODO: Need to have a more general data parser to consider color space, component types.
        for row in 0 ..< pixHeight {
            for column in 0 ..< pixWidth {
                let pixelIdx = column * pixWidth + row
                let r_raw : UInt8 = dataPtr![pixelIdx * 4]
                let g_raw : UInt8 = dataPtr![pixelIdx * 4 + 1]
                let b_raw : UInt8 = dataPtr![pixelIdx * 4 + 2]
                let a_raw : UInt8 = dataPtr![pixelIdx * 4 + 3]
                
                var gammaFloatUsed : Float = 2.2
                
                pixelData.append(pow(Float(r_raw) / 255.0, gammaFloatUsed))
                pixelData.append(pow(Float(g_raw) / 255.0, gammaFloatUsed))
                pixelData.append(pow(Float(b_raw) / 255.0, gammaFloatUsed))
                pixelData.append(pow(Float(a_raw) / 255.0, gammaFloatUsed))
            }
        }
        
        #elseif os(macOS)
        let rep : NSBitmapImageRep = loadImg!.representations[0] as! NSBitmapImageRep
        let colorSpace = rep.colorSpace
        
        let gamma = rep.value(forProperty: NSBitmapImageRep.PropertyKey.gamma)
        
        print("Color Space: \(rep.colorSpace)")
        
        let pixWidth : Int = rep.pixelsWide
        let pixHeight : Int = rep.pixelsHigh
        
        for row in 0 ..< pixHeight {
            for column in 0 ..< pixWidth {
                let color_ij = rep.colorAt(x: column, y: row)!
                
                var gammaFloatUsed : Float = 2.2
                if let gammaFloat = gamma as? Float {
                    gammaFloatUsed = gammaFloat
                }
                
                pixelData.append(pow(Float(color_ij.redComponent), gammaFloatUsed))
                pixelData.append(pow(Float(color_ij.greenComponent), gammaFloatUsed))
                pixelData.append(pow(Float(color_ij.blueComponent), gammaFloatUsed))
                pixelData.append(Float(color_ij.alphaComponent))
            }
        }
        #endif
        
        // I may have to follow the doc to copy out texture data.
        let texDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba32Float, width: pixWidth, height: pixHeight, mipmapped: false)
        
        let mtlTex = m_mtlDevice!.makeTexture(descriptor: texDesc)
        assert(mtlTex != nil, "Failed to create texture.")
        
        let cpyRegion : MTLRegion = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                              size: MTLSize(width: mtlTex!.width, height: mtlTex!.height, depth: 1))
        
        mtlTex?.replace(region: cpyRegion, mipmapLevel: 0, withBytes: pixelData, bytesPerRow: 16 * mtlTex!.width)
        return mtlTex!
    }
    
    private func CreateSampler(gltfSampler: GLTFTextureSampler) -> MTLSamplerState
    {
        var samplerDesc : MTLSamplerDescriptor = MTLSamplerDescriptor()
        samplerDesc.minFilter = .linear
        samplerDesc.magFilter = .linear
        
        switch gltfSampler.wrapS {
            case .clampToEdge:
                samplerDesc.sAddressMode = .clampToEdge
            case .mirroredRepeat:
                samplerDesc.sAddressMode = .mirrorRepeat
            case .repeat:
                samplerDesc.sAddressMode = .repeat
            @unknown default:
                fatalError()
        }
        
        switch gltfSampler.wrapT {
            case .clampToEdge:
                samplerDesc.tAddressMode = .clampToEdge
            case .mirroredRepeat:
                samplerDesc.tAddressMode = .mirrorRepeat
            case .repeat:
                samplerDesc.tAddressMode = .repeat
            @unknown default:
                fatalError()
        }
        
        return m_mtlDevice!.makeSamplerState(descriptor: samplerDesc)!
    }
    
    func AssembleVertexBuffer(iPos: UnsafeMutableRawBufferPointer,
                              iNrm: UnsafeMutableRawBufferPointer,
                              iTangent: UnsafeMutableRawBufferPointer?,
                              iUV: UnsafeMutableRawBufferPointer?,
                              iColor: (UnsafeMutableRawBufferPointer?, Int),
                              iVertSizeInBytes: Int) -> (UnsafeMutableRawBufferPointer, BoundingBox){
        let vertCnt = iPos.count / (MemoryLayout<Float>.stride * 3)
        let bufferSize = vertCnt * iVertSizeInBytes
        let pVertBuffer: UnsafeMutableRawBufferPointer = UnsafeMutableRawBufferPointer.allocate(byteCount: bufferSize, alignment: 1024)
        pVertBuffer.initializeMemory(as: UInt8.self, repeating: UInt8(0))
        
        var bboxStart: Bool = false
        var bbxMin : SIMD3<Float> = SIMD3<Float>()
        var bbxMax : SIMD3<Float> = SIMD3<Float>()
        
        for i in 0..<vertCnt{
            let startingByteOffset: Int = i * iVertSizeInBytes
            var curByteOffset: Int = startingByteOffset
            
            /// Pos
            let pPosDst = pVertBuffer.baseAddress?.advanced(by: startingByteOffset)
            
            let posSrcOffset = MemoryLayout<Float>.stride * 3 * i
            let pPosSrc = iPos.baseAddress?.advanced(by: posSrcOffset)
            pPosDst?.copyMemory(from: pPosSrc!, byteCount: MemoryLayout<Float>.stride * 3)
            
            pPosSrc?.withMemoryRebound(to: Float.self, capacity: 3, { (ptr: UnsafeMutablePointer<Float>) in
                if bboxStart == false{
                    bbxMin.x = ptr.pointee
                    bbxMin.y = ptr.advanced(by: 1).pointee
                    bbxMin.z = ptr.advanced(by: 2).pointee
                    bbxMax = bbxMin
                }else{
                    bbxMin.x = min(bbxMin.x, ptr.pointee)
                    bbxMin.y = min(bbxMin.y, ptr.advanced(by: 1).pointee)
                    bbxMin.z = min(bbxMin.z, ptr.advanced(by: 2).pointee)
                    bbxMax.x = max(bbxMax.x, ptr.pointee)
                    bbxMax.y = max(bbxMax.y, ptr.advanced(by: 1).pointee)
                    bbxMax.z = max(bbxMax.z, ptr.advanced(by: 2).pointee)
                }
            })
            
#if DEBUG && DEGPRINT
            pPosSrc?.withMemoryRebound(to: Float.self, capacity: 3, { (ptr: UnsafeMutablePointer<Float>) in
                print("<YamlSceneLoader>: pos:<", ptr.pointee, ",", ptr.advanced(by: 1).pointee, ",", ptr.advanced(by: 2).pointee, ">")
            })
#endif
            
            curByteOffset += (MemoryLayout<Float>.stride * 3)
            
            /// Normal
            let pNormalDst = pVertBuffer.baseAddress?.advanced(by: curByteOffset)
            
            let nrmSizeInByte = MemoryLayout<Float>.stride * 3
            let nrmSrcOffset = nrmSizeInByte * i
            let pNrmSrc = iNrm.baseAddress?.advanced(by: nrmSrcOffset)
            pNormalDst?.copyMemory(from: pNrmSrc!, byteCount: nrmSizeInByte)
            
#if DEBUG && DEGPRINT
            pNormalDst?.withMemoryRebound(to: Float.self, capacity: 3, { (ptr: UnsafeMutablePointer<Float>) in
                print("<YamlSceneLoader>: Normal:<", ptr.pointee, ",", ptr.advanced(by: 1).pointee, ",", ptr.advanced(by: 2).pointee, ">")
            })
#endif
            
            curByteOffset += (MemoryLayout<Float>.stride * 3)
            
            /// Color
            let pColorDst = pVertBuffer.baseAddress?.advanced(by: curByteOffset)
            let colorSizeInByte = MemoryLayout<Float>.stride * iColor.1
            if iColor.0 != nil {
                let colorSrcOffset = colorSizeInByte * i
                let pColorSrc = iColor.0!.baseAddress?.advanced(by: colorSrcOffset)
                
                var tmpColor: [Float] = [1, 1, 1, 1]
                
                pColorSrc?.withMemoryRebound(to: Float.self, capacity: iColor.1, {(ptr: UnsafeMutablePointer<Float>) in
                    for j in 0..<iColor.1 {
                        tmpColor[j] = ptr.advanced(by: j).pointee
                    }
                })
                
                pColorDst?.copyMemory(from: tmpColor, byteCount: MemoryLayout<Float>.stride * 4)
            }
            else
            {
                let noColor: [Float] = [1.0, 1.0, 1.0, 1.0]
                pColorDst?.copyMemory(from: noColor, byteCount: MemoryLayout<Float>.stride * 4)
            }
            curByteOffset += (MemoryLayout<Float>.stride * 4)
            
            /// Tangent
            if iTangent != nil{
                let pTangentDst = pVertBuffer.baseAddress?.advanced(by: curByteOffset)
                
                let tangentSizeInByte = MemoryLayout<Float>.stride * 3
                let tangentSrcOffset = tangentSizeInByte * i
                let pTangentSrc = iTangent!.baseAddress?.advanced(by: tangentSrcOffset)
                
                pTangentDst?.copyMemory(from: pTangentSrc!, byteCount: tangentSizeInByte)
                
#if DEBUG && DEGPRINT
                pTangentDst?.withMemoryRebound(to: Float.self, capacity: 3, { (ptr: UnsafeMutablePointer<Float>) in
                    print("<YamlSceneLoader>: Tangent:<", ptr.pointee, ",", ptr.advanced(by: 1).pointee, ",", ptr.advanced(by: 2).pointee, ">")
                })
#endif
                
                curByteOffset += (MemoryLayout<Float>.stride * 3)
            }
            
            /// UV
            if iUV != nil{
                let pUVDst = pVertBuffer.baseAddress?.advanced(by: curByteOffset)
                
                let uvSizeInByte = MemoryLayout<Float>.stride * 2
                let uvSrcOffset = uvSizeInByte * i
                let pUVSrc = iUV!.baseAddress?.advanced(by: uvSrcOffset)
                
                pUVDst?.copyMemory(from: pUVSrc!, byteCount: uvSizeInByte)
                
#if DEBUG && DEGPRINT
                pUVDst?.withMemoryRebound(to: Float.self, capacity: 2, { (ptr: UnsafeMutablePointer<Float>) in
                    print("<YamlSceneLoader>: UV:<", ptr.pointee, ",", ptr.advanced(by: 1).pointee, ">")
                    
                })
#endif
            }
        }
        
#if DEBUG && DEGPRINT
        pVertBuffer.withMemoryRebound(to: Float.self, { (ptr: UnsafeMutableBufferPointer<Float>) in
            for i in 0..<(ptr.count / 3){
                let idx = i * 3
                print("<YamlSceneLoader>: vert buffer double check:<", ptr[idx], ",", ptr[idx + 1], ",", ptr[idx + 2], ">")
            }
        })
#endif
        
        return (pVertBuffer, BoundingBox(min: bbxMin, max: bbxMax))
    }
    
    func VertSizeInByte(iVertLayout: VertexBufferLayout) -> Int{
        switch iVertLayout{
        case .POSITION_FLOAT3_NORMAL_FLOAT3_COLOR_FLOAT4:
            return MemoryLayout<Float>.stride * 10
        case .POSITION_FLOAT3_NORMAL_FLOAT3_COLOR_FLOAT4_TANGENT_FLOAT3_TEXCOORD0_FLOAT2:
            return MemoryLayout<Float>.stride * 15
        case .POSITION_FLOAT3_NORMAL_FLOAT3_COLOR_FLOAT4_TEXCOORD0_FLOAT2:
            return MemoryLayout<Float>.stride * 12
        default:
            assert(false, "Unrecognized vertex layout")
            return 0
        }
    }
    
    func IsIdxTypeUint32(iIdxAccessor: GLTFAccessor) -> MTLIndexType{
        if iIdxAccessor.componentType == .unsignedInt {
            return .uint32
        } else {
            return .uint16
        }
    }
    
    func ReadOutAccessorData(iAccessor: GLTFAccessor) -> UnsafeMutableRawBufferPointer{
        let bufferView = iAccessor.bufferView!
        let buffer = bufferView.buffer
        let bufferOffset = bufferView.offset + iAccessor.offset
        
        /// Calculate data bytes count for copying out
        let componentBytesCnt = GetAComponentEleBytesCnt(componentType: iAccessor.componentType)
        let dimCnt = GetComponentEleCnt(valDimension: iAccessor.dimension)
        let componentCount = iAccessor.count
        let elementBytesCnt = dimCnt * componentBytesCnt
        let dataBytesCnt = componentBytesCnt * dimCnt * componentCount
        
        let pData: UnsafeMutableRawBufferPointer = UnsafeMutableRawBufferPointer.allocate(byteCount: dataBytesCnt, alignment: 1024)
        
        if (bufferView.stride == elementBytesCnt) || (bufferView.stride == 0) {
            buffer.data?.copyBytes(to: pData, from: bufferOffset..<(dataBytesCnt + bufferOffset))
        }else {
            for i in 0..<componentCount {
                let srcByteOffset = bufferOffset + i * bufferView.stride
                let dstByteOffset = i * elementBytesCnt
                let dstPtr = UnsafeMutableRawBufferPointer.init(start: (pData.baseAddress! + dstByteOffset), count: elementBytesCnt)
                buffer.data?.copyBytes(to: dstPtr, from: srcByteOffset..<(srcByteOffset + elementBytesCnt))
            }
        }
        
        return pData
    }
    
    /// Send data doesn't change per frame to GPU Buffers. E.g. World matrix or camera matrix may changes per frame so we don't need to send that to GPU.
    /// However, vertex buffer or index buffer don't change, so we can send them to GPU.
    func SendStaticDataToGPU(iDevice: MTLDevice) {
        
        for node in m_sceneGraph.m_nodes {
            if var staticModelNode = node as? StaticModel {
                for i in 0..<staticModelNode.m_primitiveShapes.count {
                    staticModelNode.m_primitiveShapes[i].m_vertBufferMtl = iDevice.makeBuffer(
                        bytes: staticModelNode.m_primitiveShapes[i].m_vertexData!.baseAddress!,
                        length: staticModelNode.m_primitiveShapes[i].m_vertexData!.count, options: [])
                    
                    staticModelNode.m_primitiveShapes[i].m_idxBufferMtl = iDevice.makeBuffer(
                        bytes: staticModelNode.m_primitiveShapes[i].m_idxData!.baseAddress!,
                        length: staticModelNode.m_primitiveShapes[i].m_idxData!.count, options: [])
                }
            }
        }
    }
    
    func LoadYamlScene(iDevice: MTLDevice, iSceneFilePath: String) -> Bool {
        let path = URL(fileURLWithPath: m_scenePath + "/" + iSceneFilePath)
        let text = try? String(contentsOf: path, encoding: .utf8)
        
        m_mtlDevice = iDevice
        
        if text != nil {
            let decoder = YAMLDecoder()
            do {
                m_curSceneInfo = try decoder.decode(YamlSceneInfoStruct.self, from: text!)
                
                let sceneObjs = m_curSceneInfo.sceneObjs!
                for(name, sceneObj) in sceneObjs {
                    print("Name: \(name), Type: \(sceneObj.objType)")
                    
                    if sceneObj.modelPath != nil {
                        let modelPath = m_assetPath + "/" + sceneObj.modelPath!
                        let gltfModelUrl = URL(fileURLWithPath: modelPath)
                        
                        let text = try? String(contentsOf: gltfModelUrl, encoding: .utf8)
                        
                        GLTFAsset.load(with: gltfModelUrl, options: [:], handler: { (progress, status, maybeAsset, maybeError, _) in
                            DispatchQueue.main.async{
                                if status == .complete {
                                    self.m_asset = maybeAsset
                                    
                                    if maybeAsset != nil {
                                        self.SendStaticDataToGPU(iDevice: iDevice)
                                    }
                                    
                                } else if let error = maybeError {
                                    print("Failed to load glTF asset: \(error)")
                                }
                            }
                        })
                    }
                    
                }
            } catch {
                print("Unable to decode YAML: \(error)")
                return false
            }
        }
        else
        {
            return false
        }
        
        return true
    }
}
