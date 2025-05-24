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
    
    var body: some View {
        VStack {
            Spacer()
            MetalView(camVerticalRotation: $m_camVerticalRotation,
                      dist: $m_camDist,
                      camHorizontalRotation: $m_camHorizontalRotation).aspectRatio(1, contentMode: .fit)
            Spacer()
            HStack {
                Spacer()
#if os(macOS)
                Text("Vertical Rotation: \(m_camVerticalRotation)").font(.body)
#else
                Text(String(format:"Vert. Rot.: %.2f", m_camVerticalRotation)).font(.system(size: 12))
#endif
                Slider(value: $m_camVerticalRotation, in: -0.785...0.785).frame(width: 200)
                
                
                Spacer()
            }
            Spacer()
            HStack {
                Spacer()
#if os(macOS)
                Text("Horizontal Rotation: \(m_camHorizontalRotation)").font(.body)
#else
                Text(String(format:"Horiz. Rot.: %.2f", m_camHorizontalRotation)).font(.system(size: 12))
#endif
                Slider(value: $m_camHorizontalRotation, in: 0...6.28319).frame(width: 200)
                Spacer()
            }
            Spacer()
            HStack {
                Spacer()
#if os(macOS)
                Text("Distance: \(m_camDist)").font(.body)
#else
                Text(String(format:"Dist: %.2f", m_camDist)).font(.system(size: 12))
#endif
                Slider(value: $m_camDist, in: 0...10).frame(width: 200)
                Spacer()
            }
            Spacer()
        }
        /*
        .onChange(of: rotation,
                   {
            oldValue, newValue in print("Slider value changed from \(oldValue) to \(newValue).")
        })*/
    }
}

#Preview {
    ContentView()
}
