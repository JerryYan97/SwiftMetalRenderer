//
//  MetalView.swift
//  SwiftMetalRenderer
//
//  Created by Jiarui Yan on 3/15/25.
//

import MetalKit
import SwiftUI

let g_renderer = MetalRenderer()

#if os(iOS)
struct MetalView: UIViewRepresentable {
    @Binding var rotation: Float
    
    func makeUIView(context: Context) -> some UIView {
        let view = MTKView()
        
        view.clearDepth = 1.0
        view.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1)
        view.device = g_renderer.m_device
        view.delegate = g_renderer
        
        return view
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context){
        g_renderer.updateRotation(angle: rotation)
    }
}
#elseif os(macOS)
struct MetalView: NSViewRepresentable {
    // @State private var renderer: MetalRenderer = MetalRenderer()
    
    @Binding var camVerticalRotation: Float
    @Binding var dist: Float
    @Binding var camHorizontalRotation: Float
    
    
    func makeNSView(context: Context) -> some NSView {
        let view = MTKView()
        
        view.clearDepth = 1.0
        view.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1)
        view.device = g_renderer.m_device
        view.delegate = g_renderer
        
        return view
    }
    
    func updateNSView(_ nsView: NSViewType, context: Context){
        // g_renderer.updateRotation(angle: rotation)
        g_renderer.updateCamera(verticalRotation: camVerticalRotation,
                                horizontalRotation: camHorizontalRotation,
                                distance: dist)
    }
}
#endif
