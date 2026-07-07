//
//  ContentView.swift
//  drivercompanion Watch App
//
//  Created by Michelle Nathania on 05/07/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack (spacing: 20) {
            Image("IdleMascot")
                .resizable()
                .scaledToFit()
            
            Text("Continue driving.")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
