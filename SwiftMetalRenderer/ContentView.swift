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
                Text("Vertical Rotation: \(m_camVerticalRotation)")
                Slider(value: $m_camVerticalRotation, in: -0.785...0.785).frame(width: 200)
                Spacer()
            }
            Spacer()
            HStack {
                Spacer()
                Text("Horizontal Rotation: \(m_camHorizontalRotation)")
                Slider(value: $m_camHorizontalRotation, in: 0...6.28319).frame(width: 200)
                Spacer()
            }
            Spacer()
            HStack {
                Spacer()
                Text("Distance: \(m_camDist)")
                Slider(value: $m_camDist, in: 0...10).frame(width: 200)
                Spacer()
            }
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
