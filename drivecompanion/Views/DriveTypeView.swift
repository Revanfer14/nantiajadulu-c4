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
    
    // Ambil teks respons terakhir dari LLM Gemini di dalam history
    private var lastLLMResponse: String {
        viewModel.history.last(where: { $0.role == .model })?.text ?? "Menemanimu di perjalanan..."
    }
    
    var body: some View {
        ZStack {
            // 1. KOREKSI BACKGROUND: Menggunakan secondarySystemBackground (Abu-abu lembut)
            // agar balon kata putih/biru muda bisa terlihat kontras seperti di gambar
            if state == .microsleep {
                Color.red.edgesIgnoringSafeArea(.all)
            } else {
                Color(.secondarySystemBackground).edgesIgnoringSafeArea(.all)
            }
            
            VStack(spacing: 0) {
                // HEDER UTAMA: Maskot & Status Kamera/Peta
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 16) {
                            Image(systemName: "camera.viewfinder")
                            Image(systemName: "map")
                        }
                        .font(.title3)
                        .padding(10)
                        // Tombol atas di gambar berwarna putih bersih
                        .background(state == .microsleep ? Color.black.opacity(0.2) : Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // BAGIAN MASKOT
//                    MascotView(state: state)
//                        .frame(maxHeight: 280)
//                        .padding(.vertical)
                }
                
                // AREA TENGAH KE BAWAH: Tampilan Balon Kata (ChatView)
                GeometryReader { geometry in
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack {
                                Spacer(minLength: 0) // Memaksa balon kata kumpul di bawah dekat tombol
                                
                                VStack(spacing: 10) {
                                    ForEach(viewModel.history.indices, id: \.self) { index in
                                        let turn = viewModel.history[index]
                                        ChatBubble(turn: turn)
                                            .id(index)
                                    }
                                }
                            }
                            .frame(minHeight: geometry.size.height, alignment: .bottom)
                            .padding(.horizontal)
                        }
                        .onChange(of: viewModel.history.count) {
                            if viewModel.history.count > 0 {
                                withAnimation {
                                    proxy.scrollTo(viewModel.history.count - 1, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                
                // KONTROL BAWAH: Tombol Berhenti Mengemudi & Pemicu Mic
                HStack(spacing: 16) {
                    Button(action: {
                        viewModel.stop()
                    }) {
                        Text("Berhenti Mengemudi")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(state == .microsleep ? Color.black : Color(red: 35/255, green: 79/255, blue: 146/255))
                            .clipShape(Capsule())
                    }
                    
                    // Indikator/Tombol Mikrofon (Warna putih bersih di kondisi normal)
                    Circle()
                        .fill(state == .microsleep ? Color.black.opacity(0.2) : Color(.systemBackground))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: viewModel.status == .listening ? "mic.fill" : "mic")
                                .foregroundColor(.blue)
                                .font(.title3)
                        )
                }
                .padding()
                // 2. KOREKSI KONTROL BAWAH: Menghilangkan background putih solidnya
                // agar menyatu mulus dengan warna latar belakang abu-abu di atasnya
                .background(state == .microsleep ? Color.red : Color.clear)
            }
        }
    }
}
