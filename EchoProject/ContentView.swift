//
//  ContentView.swift
//  EchoProject
//
//  Created by Jay Chauhan on 1/27/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject var voiceRecorder = VoiceRecorder()
    @StateObject var storage = RecordingStorage()
    @State private var showPlayback = false
    @State private var selectedRecording: Recording?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background & Glow
                Color.black.ignoresSafeArea()
                
                // Floating particles
                ParticleView()
                    .ignoresSafeArea()
                
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
                
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Main Recording Section - takes full screen height
                        VStack(spacing: 20) {
                            Text("Voice Recorder")
                                .font(.title)
                                .padding(.top, 40)
                                .foregroundStyle(.red)
                            
                            Spacer()
                            
                            Button(action: {
                                if voiceRecorder.isRecording {
                                    voiceRecorder.stopRecording()
                                    
                                    // Save recording
                                    if let recording = voiceRecorder.getCurrentRecording() {
                                        storage.saveRecording(recording)
                                    }
                                    
                                    showPlayback = true
                                } else {
                                    voiceRecorder.startRecording()
                                }
                            }) {
                                Image(systemName: voiceRecorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 100, height: 100)
                                    .foregroundColor(.red)
                            }
                            
                            Text(voiceRecorder.isRecording ? "Recording..." : "Tap to record")
                                .font(.headline)
                                .padding()
                                .foregroundStyle(.gray)
                            
                            Spacer()
                        }
                        .frame(height: UIScreen.main.bounds.height - 150)
                        
                        // Past Recordings Section - Grid below
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Past Recordings")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            if storage.recordings.isEmpty {
                                Text("No recordings yet")
                                    .font(.subheadline)
                                    .foregroundStyle(.gray)
                                    .padding(.horizontal)
                                    .padding(.bottom, 40)
                            } else {
                                LazyVGrid(columns: [
                                    GridItem(.flexible(), spacing: 15),
                                    GridItem(.flexible(), spacing: 15),
                                    GridItem(.flexible(), spacing: 15)
                                ], spacing: 15) {
                                    ForEach(storage.recordings) { recording in
                                        Button(action: {
                                            selectedRecording = recording
                                            voiceRecorder.loadRecording(recording)
                                            showPlayback = true
                                        }) {
                                            VStack(spacing: 8) {
                                                Image(systemName: "waveform")
                                                    .font(.system(size: 30))
                                                    .foregroundStyle(.red)
                                                
                                                Text(recording.date, style: .date)
                                                    .font(.caption2)
                                                    .foregroundStyle(.white)
                                                    .lineLimit(1)
                                                
                                                Text(formatDuration(recording.duration))
                                                    .font(.caption2)
                                                    .foregroundStyle(.gray)
                                            }
                                            .padding()
                                            .frame(maxWidth: .infinity)
                                            .aspectRatio(1, contentMode: .fit)
                                            .background(Color.white.opacity(0.1))
                                            .cornerRadius(12)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 100)
                            }
                        }
                        .opacity(voiceRecorder.isRecording ? 0 : 1)
                        .animation(.easeInOut(duration: 0.3), value: voiceRecorder.isRecording)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
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
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    ContentView()
}
