//
//  YamlSceneLoader.swift
//  SwiftMetalRenderer
//
//  Created by Jiarui Yan on 3/16/25.
//
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
    case POSITION_FLOAT3_NORMAL_FLOAT3_TANGENT_FLOAT3_TEXCOORD0_FLOAT2
    case POSITION_FLOAT3_NORMAL_FLOAT3_TEXCOORD0_FLOAT2
    case POSITION_FLOAT3_NORMAL_FLOAT3
}

func ChooseVertexBufferLayout(hasTangent: Bool, hasTexCoord: Bool) -> VertexBufferLayout{
    var res: VertexBufferLayout = .POSITION_FLOAT3_NORMAL_FLOAT3
    if hasTangent {
        res = .POSITION_FLOAT3_NORMAL_FLOAT3_TANGENT_FLOAT3_TEXCOORD0_FLOAT2
    } else {
        if hasTexCoord {
            res = .POSITION_FLOAT3_NORMAL_FLOAT3_TEXCOORD0_FLOAT2
        }
    }
    
    return res
}

func VertexBufferLayoutAttributeCount(iLayout: VertexBufferLayout) -> Int {
    switch iLayout {
    case .POSITION_FLOAT3_NORMAL_FLOAT3:
        return 2
    case .POSITION_FLOAT3_NORMAL_FLOAT3_TANGENT_FLOAT3_TEXCOORD0_FLOAT2:
        return 4
    case .POSITION_FLOAT3_NORMAL_FLOAT3_TEXCOORD0_FLOAT2:
        return 3
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

/*
class BaseMaterial
{
    let m_materialType: MaterialType
    
    init(materialType: MaterialType) {
        self.m_materialType = materialType
    }
}

class ConstantMaterial : BaseMaterial
{
    let m_diffuseColor: [Float]
    
    init(diffuseColor: [Float]) {
        self.m_diffuseColor = diffuseColor
        super.init(materialType: .Constant)
    }
}
*/

class Material
{
    var m_baseColorFactor: [Float]?
    var m_metallicFactor: Float?
    var m_roughnessFactor: Float?
    
    var m_baseColorTexture: MTLTexture?
    var m_metallicRoughnessTexture: MTLTexture?
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
}

class StaticModel : SceneNode {
    var m_primitiveShapes: [PrimitiveShape] = []
    var m_worldMatrix: [Float] = []
}

class Camera : SceneNode {
    var m_worldMatrix: [Float] = []
    var m_fov: Float = 0.0
    var m_aspectRatio: Float = 0.0
    
    func GetViewMatrix() -> [Float] {
        return [0.0]
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
    
    var m_sceneGraph: SceneGraph
    var m_asset: GLTFAsset? {
        didSet{
            if m_asset != nil {
                // Parsing the gltf asset
                print("Intercept m_asset")
                let assetRef = m_asset!
                
                for meshIdx in 0..<assetRef.meshes.count {
                    let meshRef = assetRef.meshes[meshIdx]
                    var staticModelNode: StaticModel = StaticModel(iObjType: Optional.none, iObjName: Optional.none)
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
                        }
                        
                        /// Construct the vertex buffer and index buffer
                        var primShape: PrimitiveShape = PrimitiveShape()
                        let vertLayout = ChooseVertexBufferLayout(hasTangent: tanAttribute != nil,
                                                                  hasTexCoord: uvAttribute != nil)
                        primShape.m_vertexLayout = vertLayout
                        primShape.m_idxData = ReadOutAccessorData(iAccessor: prim.indices!)
                        primShape.m_idxType = IsIdxTypeUint32(iIdxAccessor: prim.indices!)
                        primShape.m_idxCnt = prim.indices!.count
                        primShape.m_vertexData = AssembleVertexBuffer(iPos: pPosData,
                                                                      iNrm: pNormalData,
                                                                      iTangent: pTangentData,
                                                                      iUV: pUVData,
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
                        
                        var shapeMaterial : Material = Material()
                        
                        if baseColorTex != nil{
                            assert(false, "Need to support base color texture.")
                        } else {
                            let baseColorFactor : [Float] = [baseColorFactor.x,
                                                             baseColorFactor.y,
                                                             baseColorFactor.z,
                                                             baseColorFactor.w]
                            
                            shapeMaterial.m_baseColorFactor = baseColorFactor
                        }
                        
                        if metallicRoughnessTex != nil{
                            assert(false, "Need to support metallicRoughness texture.")
                        } else {
                            let metallicFactor : Float = primMaterial.metallicRoughness!.metallicFactor
                            let roughnessFactor : Float = primMaterial.metallicRoughness!.roughnessFactor
                            
                            shapeMaterial.m_roughnessFactor = roughnessFactor
                            shapeMaterial.m_metallicFactor = metallicFactor
                        }
                        
                        primShape.m_material = shapeMaterial
                        
                        staticModelNode.m_primitiveShapes.append(primShape)
                    }
                    m_sceneGraph.m_nodes.append(staticModelNode)
                }
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
    
    func AssembleVertexBuffer(iPos: UnsafeMutableRawBufferPointer,
                              iNrm: UnsafeMutableRawBufferPointer,
                              iTangent: UnsafeMutableRawBufferPointer?,
                              iUV: UnsafeMutableRawBufferPointer?,
                              iVertSizeInBytes: Int) -> UnsafeMutableRawBufferPointer{
        let vertCnt = iPos.count / (MemoryLayout<Float>.stride * 3)
        let bufferSize = vertCnt * iVertSizeInBytes
        let pVertBuffer: UnsafeMutableRawBufferPointer = UnsafeMutableRawBufferPointer.allocate(byteCount: bufferSize, alignment: 1024)
        
        for i in 0..<vertCnt{
            let startingByteOffset: Int = i * iVertSizeInBytes
            var curByteOffset: Int = startingByteOffset
            
            /// Pos
            let pPosDst = pVertBuffer.baseAddress?.advanced(by: startingByteOffset)
            
            let posSrcOffset = MemoryLayout<Float>.stride * 3 * i
            let pPosSrc = iPos.baseAddress?.advanced(by: posSrcOffset)
            pPosDst?.copyMemory(from: pPosSrc!, byteCount: MemoryLayout<Float>.stride * 3)
            
#if DEBUG
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
            
#if DEBUG
            pNormalDst?.withMemoryRebound(to: Float.self, capacity: 3, { (ptr: UnsafeMutablePointer<Float>) in
                print("<YamlSceneLoader>: Normal:<", ptr.pointee, ",", ptr.advanced(by: 1).pointee, ",", ptr.advanced(by: 2).pointee, ">")
            })
#endif
            
            curByteOffset += (MemoryLayout<Float>.stride * 3)
            
            /// Tangent
            if iTangent != nil{
                let pTangentDst = pVertBuffer.baseAddress?.advanced(by: curByteOffset)
                
                let tangentSizeInByte = MemoryLayout<Float>.stride * 3
                let tangentSrcOffset = tangentSizeInByte * i
                let pTangentSrc = iTangent!.baseAddress?.advanced(by: tangentSrcOffset)
                
                pTangentDst?.copyMemory(from: pTangentSrc!, byteCount: tangentSizeInByte)
                
#if DEBUG
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
                
#if DEBUG
                pUVDst?.withMemoryRebound(to: Float.self, capacity: 2, { (ptr: UnsafeMutablePointer<Float>) in
                    print("<YamlSceneLoader>: UV:<", ptr.pointee, ",", ptr.advanced(by: 1).pointee, ">")
                    
                })
#endif
            }
        }
        
#if DEBUG
        pVertBuffer.withMemoryRebound(to: Float.self, { (ptr: UnsafeMutableBufferPointer<Float>) in
            for i in 0..<(ptr.count / 3){
                let idx = i * 3
                print("<YamlSceneLoader>: vert buffer double check:<", ptr[idx], ",", ptr[idx + 1], ",", ptr[idx + 2], ">")
            }
        })
#endif
        
        
        return pVertBuffer
    }
    
    func VertSizeInByte(iVertLayout: VertexBufferLayout) -> Int{
        switch iVertLayout{
        case .POSITION_FLOAT3_NORMAL_FLOAT3:
            return MemoryLayout<Float>.stride * 6
        case .POSITION_FLOAT3_NORMAL_FLOAT3_TANGENT_FLOAT3_TEXCOORD0_FLOAT2:
            return MemoryLayout<Float>.stride * 11
        case .POSITION_FLOAT3_NORMAL_FLOAT3_TEXCOORD0_FLOAT2:
            return MemoryLayout<Float>.stride * 8
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
                        /*
                        GLTFAsset.load(with: gltfModelUrl, options: [:]) { (progress, status, maybeAsset, maybeError, _) in
                            DispatchQueue.main.async {
                                if status == .complete {
                                    self.m_asset = maybeAsset
                                    
                                    if maybeAsset != nil {
                                        self.SendStaticDataToGPU(iDevice: iDevice)
                                    }
                                    
                                } else if let error = maybeError {
                                    print("Failed to load glTF asset: \(error)")
                                }
                            }
                        }
                         */
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
