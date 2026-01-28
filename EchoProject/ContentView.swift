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
    @State private var isAnalyzing = false
    @State private var selectedRecording: Recording?
    @State private var recordingToDelete: Recording?
    @State private var showDeleteAlert = false
    
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
                            Spacer()
                            
                            Button(action: {
                                if voiceRecorder.isRecording {
                                    voiceRecorder.stopRecording()
                                    withAnimation { isAnalyzing = true }
                                    
                                    Task { @MainActor in
                                        // Save recording
                                        if let recording = await voiceRecorder.getCurrentRecording() {
                                            storage.saveRecording(recording)
                                            selectedRecording = recording
                                            
                                            // Artificial delay if analysis is too fast (optional, but good for UX)
                                            try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                                            
                                            withAnimation {
                                                isAnalyzing = false
                                                showPlayback = true
                                            }
                                        } else {
                                            withAnimation { isAnalyzing = false }
                                        }
                                    }
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
                                            .background(.ultraThinMaterial)
                                            .cornerRadius(12)
                                        }
                                        .onLongPressGesture {
                                            recordingToDelete = recording
                                            showDeleteAlert = true
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
                .safeAreaInset(edge: .top) {
                    Text("Echo 🎤")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                
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
                
                // Analysis Loading Screen
                if isAnalyzing {
                    ZStack {
                        Color.black.ignoresSafeArea()
                        ParticleView().ignoresSafeArea().opacity(0.5)
                        
                        VStack(spacing: 30) {
                            AnalysisLoadingView()
                                .frame(width: 200, height: 200)
                            
                            Text("Analyzing Audio...")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .opacity(0.8)
                        }
                    }
                    .transition(.opacity)
                    .zIndex(2)
                }
            }
            .navigationDestination(isPresented: $showPlayback) {
                if let recording = selectedRecording {
                    PlaybackView(voiceRecorder: voiceRecorder, storage: storage, recording: recording)
                }
            }
            .onAppear {
                voiceRecorder.requestPermission()
            }
        }
        .alert("Delete Recording", isPresented: $showDeleteAlert, presenting: recordingToDelete) { recording in
            Button("Cancel", role: .cancel) { }
                .tint(.white)
            Button("Delete", role: .destructive) {
                storage.deleteRecording(recording)
            }
            .tint(.red)
        } message: { recording in
            Text("Are you sure you want to delete \"\(getRecordingName(recording))\"?")
        }
        .preferredColorScheme(.dark)
    }
    
    private func getRecordingName(_ recording: Recording) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        let fullName = formatter.string(from: recording.date)
        return fullName.count > 20 ? String(fullName.prefix(20)) + "..." : fullName
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    // Preview with analysis state true to see animation
    ContentView()
}

struct AnalysisLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Central Core
            Circle()
                .fill(Color.red)
                .frame(width: 60, height: 60)
                .blur(radius: isAnimating ? 20 : 10)
                .scaleEffect(isAnimating ? 1.2 : 0.8)
            
            Circle()
                .fill(Color.white)
                .frame(width: 30, height: 30)
                .scaleEffect(isAnimating ? 1.0 : 0.5)
                .blur(radius: 5)
                .opacity(0.8)
            
            // Orbiting Rings
            ForEach(0..<3) { i in
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        AngularGradient(gradient: Gradient(colors: [.red.opacity(0), .red]), center: .center),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: CGFloat(100 + i * 40), height: CGFloat(100 + i * 40))
                    .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                    .animation(
                        Animation.linear(duration: Double(3 - i) + 1.0)
                            .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}
