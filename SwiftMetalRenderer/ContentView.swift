//
//  ContentView.swift
//  SwiftMetalRenderer
//
//  Created by Jiarui Yan on 3/11/25.
//

import SwiftUI

struct ContentView: View {
    @State private var rotation: Float = 0.0
    
    var body: some View {
        VStack {
            Spacer()
            MetalView(rotation: $rotation).aspectRatio(1, contentMode: .fit)
            Spacer()
        }.onChange(of: rotation,
                   {
            oldValue, newValue in print("Slider value changed from \(oldValue) to \(newValue).")
        })
    }
}

#Preview {
    ContentView()
}
