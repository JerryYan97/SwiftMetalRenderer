//
//  MetalView.swift
//  SwiftMetalRenderer
//
//  Created by Jiarui Yan on 3/15/25.
//

import MetalKit
import SwiftUI

#if os(iOS)
struct MetalView: UIViewRepresentable {
    @State private var renderer: MetalRenderer = MetalRenderer()
    
    @Binding var rotation: Float
    
    func makeUIView(context: Context) -> some UIView {
        let view = MTKView()
        
        view.clearDepth = 1.0
        view.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1)
        view.device = renderer.m_device
        view.delegate = renderer
        
        return view
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context){
        renderer.updateRotation(angle: rotation)
    }
}
#elseif os(macOS)
struct MetalView: NSViewRepresentable {
    @State private var renderer: MetalRenderer = MetalRenderer()
    
    @Binding var rotation: Float
    
    func makeNSView(context: Context) -> some NSView {
        let view = MTKView()
        
        view.clearDepth = 1.0
        view.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1)
        view.device = renderer.m_device
        view.delegate = renderer
        
        return view
    }
    
    func updateNSView(_ nsView: NSViewType, context: Context){
        renderer.updateRotation(angle: rotation)
    }
}
#endif
