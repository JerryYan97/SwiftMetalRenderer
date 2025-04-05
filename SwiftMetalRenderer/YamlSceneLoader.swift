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
    case None
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
    let m_objType: SceneObjectType
    let m_objName: String
    
    init(iObjType: SceneObjectType, iObjName: String){
        m_objType = iObjType
        m_objName = iObjName
    }
}

struct PrimitiveShape {
    var m_vertexLayout: VertexBufferLayout
    var m_vertexData: UnsafeMutableRawBufferPointer
    
    var m_idxType: Bool // 0: uint16_t, 1: uint32_t
    var m_idxData: UnsafeMutableRawBufferPointer
}

class StaticModel : SceneNode {
    var m_primitiveShapes: [PrimitiveShape] = []
    
}

class Camera : SceneNode {
    
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
    
    var m_sceneGraph: SceneGraph
    var m_asset: GLTFAsset? {
        didSet{
            if m_asset != nil {
                // Parsing the gltf asset
                print("Intercept m_asset")
                let assetRef = m_asset!
                for meshIdx in 0..<assetRef.meshes.count {
                    let meshRef = assetRef.meshes[meshIdx]
                    var staticModelNode: StaticModel = StaticModel()
                    // Currently only support a single mesh:
                    for primitiveIdx in 0..<meshRef.primitives.count {
                        let prim = meshRef.primitives[primitiveIdx]
                        let posAttribute = prim.attribute(forName: "POSITION")
                        let nrmAttribute = prim.attribute(forName: "NORMAL")
                        let tanAttribute = prim.attribute(forName: "TANGENT")
                        let uvAttribute = prim.attribute(forName: "TEXCOORD_0")
                        
                        assert(posAttribute != nil, "A primitive must have a POSITION attribute")
                        assert(posAttribute!.accessor.componentType == .float, "POSITION attribute must be float components")
                        assert(posAttribute!.accessor.dimension == .vector3, "POSITION attribute must be 3D vector")
                        /// Load Position
                        let pPosData = ReadOutAccessorData(iAccessor: posAttribute!.accessor)
                        
                        /// Load Normal
                        let pNormalData = ReadOutAccessorData(iAccessor: nrmAttribute!.accessor)
                        
                        /// Load Tangent
                        var pTangentData : UnsafeMutableRawBufferPointer
                        if(tanAttribute != nil){
                            pTangentData = ReadOutAccessorData(iAccessor: tanAttribute!.accessor)
                        }
                        
                        /// Construct the vertex buffer and index buffer
                        var primShape: PrimitiveShape
                        primShape.m_vertexLayout = ChooseVertexBufferLayout(hasTangent: tanAttribute != nil,
                                                                            hasTexCoord: uvAttribute != nil)
                        
                        
                        
                        
                        
                        pPosData.withMemoryRebound(to: Float.self) { (ptr: UnsafeMutableBufferPointer<Float>) in
                            let cnt = ptr.count
                            for eleIdx in 0..<(cnt / 3) {
                                print("Pos<", ptr[eleIdx * 3], ",", ptr[eleIdx * 3 + 1], ",", ptr[eleIdx * 3 + 2], ">")
                            }
                        }
                        
                        
                        print("Interception")
                        
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
    }
    
    func ReadOutAccessorData(iAccessor: GLTFAccessor) -> UnsafeMutableRawBufferPointer{
        let bufferView = iAccessor.bufferView!
        let buffer = bufferView.buffer
        
        /// Calculate data bytes count for copying out
        let componentBytesCnt = GetAComponentEleBytesCnt(componentType: iAccessor.componentType)
        let dimCnt = GetComponentEleCnt(valDimension: iAccessor.dimension)
        let componentCount = iAccessor.count
        let elementBytesCnt = dimCnt * componentBytesCnt
        let dataBytesCnt = componentBytesCnt * dimCnt * componentCount
        
        let pData: UnsafeMutableRawBufferPointer = UnsafeMutableRawBufferPointer.allocate(byteCount: dataBytesCnt, alignment: 1024)
        
        if bufferView.stride == elementBytesCnt {
            buffer.data?.copyBytes(to: pData, from: bufferView.offset...(dataBytesCnt + bufferView.offset))
        }else {
            for i in 0..<componentCount {
                let srcByteOffset = bufferView.offset + i * bufferView.stride
                let dstByteOffset = i * elementBytesCnt
                let dstPtr = UnsafeMutableRawBufferPointer.init(start: (pData.baseAddress! + dstByteOffset), count: elementBytesCnt)
                buffer.data?.copyBytes(to: dstPtr, from: srcByteOffset..<(srcByteOffset + elementBytesCnt))
            }
        }
        
        return pData
    }
    
    func LoadYamlScene(iSceneFilePath: String) -> Bool {
        let path = URL(fileURLWithPath: iSceneFilePath)
        let text = try? String(contentsOf: path, encoding: .utf8)

        if text != nil {
            let decoder = YAMLDecoder()
            do {
                m_curSceneInfo = try decoder.decode(YamlSceneInfoStruct.self, from: text!)
                
                let assetDir = "/Users/jiaruiyan/Projects/SwiftMetalRenderer/SwiftMetalRenderer/assets"
                
                let sceneObjs = m_curSceneInfo.sceneObjs!
                for(name, sceneObj) in sceneObjs {
                    print("Name: \(name), Type: \(sceneObj.objType)")
                    
                    if sceneObj.modelPath != nil {
                        let modelPath = assetDir + "/" + sceneObj.modelPath!
                        let gltfModelUrl = URL(fileURLWithPath: modelPath)
                        GLTFAsset.load(with: gltfModelUrl, options: [:], handler: { (progress, status, maybeAsset, maybeError, _) in
                            DispatchQueue.main.async{
                                if status == .complete {
                                    self.m_asset = maybeAsset
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
