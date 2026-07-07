//
//  DrivingView.swift
//  drivercompanion Watch App
//
//  Created by Michelle Nathania on 06/07/26.
//

import SwiftUI

struct DrivingView: View {
    @StateObject private var connectivity = WatchConnectivityManager.shared
    
    var body: some View {
        VStack (spacing: 20) {
            
            VStack (spacing: 20) {
                Image(connectivity.state.watchMascotImage)
                    .resizable()
                    .scaledToFit()
                
                Text(connectivity.state.watchMascotText)
            }
            .frame(width: 200, height: 200)
            .padding()
        }
    }
}
    
#Preview {
    DrivingView()
}
