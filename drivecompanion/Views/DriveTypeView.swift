//
//  DriveTypeView.swift
//  drivecompanion
//
//  Created by Stephanie Vania Suwardi Data on 06/07/26.
//

import SwiftUI

struct DrivingTypeView: View {
    @ObservedObject var viewModel: AIViewModel
    let state: DrowsinessState

    var body: some View {
        ZStack {
            if state == .microsleep {
                Color.red.ignoresSafeArea()
            } else {
                Color(.systemBackground).ignoresSafeArea()
            }

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Image(systemName: "camera.viewfinder")
                            .font(.title3)
                            .foregroundStyle(Color(red: 52/255.0, green: 199/255.0, blue: 89/255.0))
                            .frame(width: 44, height: 44)
                            .background(Color(.systemBackground).opacity(state == .microsleep ? 0.15 : 1))
                            .clipShape(Circle())
                            .glassEffect()

                        Image(systemName: "map")
                            .font(.title3)
                            .foregroundStyle(state == .microsleep ? Color.white : Color.primary)
                            .frame(width: 44, height: 44)
                            .background(Color(.systemBackground).opacity(state == .microsleep ? 0.15 : 1))
                            .clipShape(Circle())
                            .glassEffect()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)                    
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()

                VStack(spacing: 0) {
                    Image(systemName: "figure.wave")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 160)
                        .foregroundStyle(AppColor.appPrimary)

                    Ellipse()
                        .fill(Color(.systemGray5).opacity(0.7))
                        .frame(width: 160, height: 40)
                        .offset(y: -10)
                }

                Spacer()

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(viewModel.history.indices, id: \.self) { index in
                                ChatBubble(turn: viewModel.history[index])
                                    .id(index)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                    }
                    .frame(height: 260)
                    .onChange(of: viewModel.history.count) {
                        if viewModel.history.count > 0 {
                            withAnimation {
                                proxy.scrollTo(viewModel.history.count - 1, anchor: .bottom)
                            }
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        viewModel.stop()
                    } label: {
                        Text("Berhenti Mengemudi")
                            .font(.headline)
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(state == .microsleep ? Color.black : AppColor.appPrimary)
                            .clipShape(Capsule())
                            .glassEffect()
                    }

                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 54, height: 54)
                        .overlay(
                            Image(systemName: viewModel.status == .listening ? "mic.fill" : "mic")
                                .foregroundStyle(Color(red: 0, green: 136/255.0, blue: 1))
                                .font(.title3)
                        )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(state == .microsleep ? Color.red : Color.clear)
            }
        }
    }
}
