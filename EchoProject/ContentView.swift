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
            VStack {
                Text("Voice Recorder")
                    .font(.title)
                    .padding()
                    .foregroundStyle(.white)
                
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
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
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
