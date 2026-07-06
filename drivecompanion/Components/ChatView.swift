//
//  ChatView.swift
//  drivecompanion
//
//  Created by Stephanie Vania Suwardi Data on 06/07/26.
//

import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: AIViewModel
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(viewModel.history.indices, id: \.self) { index in
                        let turn = viewModel.history[index]
                        
                        // balon kataa
                        ChatBubble(turn: turn)
                            .id(index)
                            .padding(.top, 150)
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.history.count) {
               
                if viewModel.history.count > 0 {
                    withAnimation {
                        proxy.scrollTo(viewModel.history.count - 1, anchor: .bottom)
                    }
                }
            }
        }
        .navigationTitle("Sohib Nyetir")
    }
}

