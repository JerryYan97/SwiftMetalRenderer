//
//  ContentView.swift
//  SwiftMetalRenderer
//
//  Created by Jiarui Yan on 3/11/25.
//

import SwiftUI

struct ContentView: View {
    @State private var m_camHorizontalRotation: Float = 0.0
    @State private var m_camDist: Float = 5.0
    @State private var m_camVerticalRotation: Float = 0.0
    @State private var m_ptLightIntensity: Float = 10.0
    @State private var m_ambientLightIntensity: Float = 0.1
    
    var body: some View {
        VStack {
            Spacer()
            MetalView(camVerticalRotation: $m_camVerticalRotation,
                      dist: $m_camDist,
                      camHorizontalRotation: $m_camHorizontalRotation,
                      ptLightIntensity: $m_ptLightIntensity,
                      ambientLightIntensity: $m_ambientLightIntensity).aspectRatio(1, contentMode: .fit)
            Spacer()
            HStack {
#if os(macOS)
                Text("Vertical Rotation: \(m_camVerticalRotation)").font(.body)
#else
                Text(String(format:"Vert. Rot.: %.2f", m_camVerticalRotation)).font(.system(size: 12))
#endif
                Slider(value: $m_camVerticalRotation, in: -0.785...0.785).frame(width: 200)
            }
            Spacer()
            HStack {
#if os(macOS)
                Text("Horizontal Rotation: \(m_camHorizontalRotation)").font(.body)
#else
                Text(String(format:"Horiz. Rot.: %.2f", m_camHorizontalRotation)).font(.system(size: 12))
#endif
                Slider(value: $m_camHorizontalRotation, in: 0...6.28319).frame(width: 200)
            }
            Spacer()
            HStack {
#if os(macOS)
                Text("Distance: \(m_camDist)").font(.body)
#else
                Text(String(format:"Dist: %.2f", m_camDist)).font(.system(size: 12))
#endif
                Slider(value: $m_camDist, in: 0...10).frame(width: 200)
            }
            Spacer()
            
            HStack{
#if os(macOS)
                Text(String(format: "Pt Light Intensity: %.2f", m_ptLightIntensity)).font(.body)
#else
                Text(String(format: "Pt: %.1f", m_ptLightIntensity)).font(.system(size: 12))
#endif
                Slider(value: $m_ptLightIntensity, in: 0...40).frame(width: 90)
                
#if os(macOS)
                Text(String(format: "Ambient Light Intensity: %.2f", m_ambientLightIntensity)).font(.body)
#else
                Text(String(format: "Amb.: %.1f", m_ambientLightIntensity)).font(.system(size: 12))
#endif
                Slider(value: $m_ambientLightIntensity, in: 0...20).frame(width: 90)
            }
            Spacer()
        }
    }
}

#Preview {
    ContentView()
}
