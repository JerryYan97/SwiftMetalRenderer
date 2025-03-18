//
//  YamlSceneLoader.swift
//  SwiftMetalRenderer
//
//  Created by Jiarui Yan on 3/16/25.
//
import Foundation
import Yams

enum SceneObjectType {
    case None
    case StaticModel
    case Camera
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

class StaticModel : SceneNode {
    
}

class Camera : SceneNode {
    
}

struct SceneGraph {
    var m_nodes: [String: SceneNode]
}

struct YamlSceneLoader {
    
}

class SceneManager
{
    var m_curSceneInfo: YamlSceneInfoStruct
    
    let m_sceneGraph: SceneGraph
    
    
    init(){
        m_sceneGraph = SceneGraph(m_nodes: [:])
        m_curSceneInfo = YamlSceneInfoStruct(sceneName: "", version: nil, sceneObjs: nil)
    }
    
    func LoadYamlScene(iSceneFilePath: String) -> Bool {
        let path = URL(fileURLWithPath: iSceneFilePath)
        let text = try? String(contentsOf: path, encoding: .utf8)

        if text != nil {
            let decoder = YAMLDecoder()
            do {
                m_curSceneInfo = try decoder.decode(YamlSceneInfoStruct.self, from: text!)
                
                let sceneObjs = m_curSceneInfo.sceneObjs!
                for(name, sceneObj) in sceneObjs {
                    
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
