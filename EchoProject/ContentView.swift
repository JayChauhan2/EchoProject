//
//  ContentView.swift
//  EchoProject
//
//  Created by Jay Chauhan on 1/27/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject var voiceRecorder = VoiceRecorder()
    @State private var showPlayback = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background & Glow
                Color.black.ignoresSafeArea()
                
                if voiceRecorder.isRecording {
                    Circle()
                        .fill(
                            RadialGradient(gradient: Gradient(colors: [.red.opacity(0.6), .red.opacity(0.0)]), center: .center, startRadius: 0, endRadius: 400)
                        )
                        .blur(radius: 50)
                        .scaleEffect(1.0 + CGFloat(voiceRecorder.currentAmplitude) * 2.0)
                        .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height + 20)
                        .animation(.easeOut(duration: 0.1), value: voiceRecorder.currentAmplitude)
                }
                
                VStack {
                    Text("Voice Recorder")
                        .font(.title)
                        .padding()
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        if voiceRecorder.isRecording {
                            voiceRecorder.stopRecording()
                            showPlayback = true
                        } else {
                            voiceRecorder.startRecording()
                        }
                    }) {
                        Image(systemName: voiceRecorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .foregroundColor(.red)
                    }
                    Text(voiceRecorder.isRecording ? "Recording..." : "Tap to record")
                        .font(.headline)
                        .padding()
                        .foregroundStyle(.gray)
                    
                    Spacer()
                }
                .padding()
                
                // Live Visualizer located at the very bottom
                if voiceRecorder.isRecording {
                    VStack {
                        Spacer()
                        HStack(spacing: 3) {
                            ForEach(0..<60) { i in
                                // Elliptical/Wide Semi-circle envelope
                                // Range -30 to 30
                                let x = CGFloat(i - 30)
                                // Use a radius larger than the range to keep edges from hitting zero/too steep
                                let radius: CGFloat = 38
                                // Shape factor
                                let shapeFactor = max(0, sqrt(pow(radius, 2) - pow(x, 2))) / radius
                                
                                // Base height from amplitude + Random noise for "spiky" look
                                let noise = CGFloat.random(in: 0.5...1.5)
                                let height = CGFloat(voiceRecorder.currentAmplitude) * 200.0 * shapeFactor * noise
                                
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.red)
                                    .frame(width: 4, height: max(0, height))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .bottom)
                        .padding(.bottom, 0)
                        .offset(y: 20)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .ignoresSafeArea(edges: .bottom)
                }
            }
            .navigationDestination(isPresented: $showPlayback) {
                PlaybackView(voiceRecorder: voiceRecorder)
            }
            .onAppear {
                voiceRecorder.requestPermission()
            }
        }
        .preferredColorScheme(.dark)
        .tint(.red)
    }
}

#Preview {
    ContentView()
}
