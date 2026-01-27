import SwiftUI
import AVFoundation

struct PlaybackView: View {
    @ObservedObject var voiceRecorder: VoiceRecorder
    @ObservedObject var storage: RecordingStorage
    let recording: Recording
    
    @Environment(\.dismiss) var dismiss
    @State private var showDeleteAlert = false
    @State private var isDragging = false
    @State private var scrubbingTime: TimeInterval = 0
    
    private func formattedTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time * 100).truncatingRemainder(dividingBy: 100))
        return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
    }
    
    var body: some View {
        VStack {
            Text("Recording Playback")
                .font(.title)
                .padding()
                .foregroundStyle(.white)
            
            Spacer()
            
            // Time Display
            Text(formattedTime(isDragging ? scrubbingTime : voiceRecorder.currentTime))
                .font(.system(size: 40, weight: .light, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.bottom, 20)
            
            // Audio Visualization Graph
            ZStack {
                GeometryReader { geometry in
                    let barWidth: CGFloat = 6
                    let spacing: CGFloat = 4
                    let totalBarWidth = barWidth + spacing
                    let totalWidth = CGFloat(voiceRecorder.audioSamples.count) * totalBarWidth
                    
                    // Center the current time
                    let duration = voiceRecorder.duration > 0 ? voiceRecorder.duration : 1
                    // Use scrubbing time if dragging, else current playback time
                    let timeToShow = isDragging ? scrubbingTime : voiceRecorder.currentTime
                    
                    let percent = CGFloat(timeToShow / duration)
                    let currentX = percent * totalWidth
                    let centerOffset = geometry.size.width / 2
                    
                    VStack(alignment: .leading, spacing: 0) {
                        // Waveform
                        HStack(spacing: spacing) {
                            ForEach(voiceRecorder.audioSamples.indices, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.red)
                                    // Boost amplitude to fill height: * 400. Clamp to max 250.
                                    .frame(width: barWidth, height: min(250, max(4, CGFloat(voiceRecorder.audioSamples[index]) * 400)))
                            }
                        }
                        .frame(height: 250, alignment: .bottom) // Align bottom to sit on ruler
                        
                        // Ruler
                        ZStack(alignment: .topLeading) {
                            // Ruler Line
                            Rectangle()
                                .fill(Color.gray)
                                .frame(height: 1)
                                .frame(width: totalWidth)
                            
                            // Ticks and Labels
                            // 1 second = 20 samples * 10 width = 200 points
                            // Create range of seconds covering the duration
                            let secondsCount = Int(totalWidth / 200) + 1
                            
                            ForEach(0..<secondsCount, id: \.self) { second in
                                let xPos = CGFloat(second) * 200.0
                                
                                // Major Tick
                                Rectangle()
                                    .fill(Color.gray)
                                    .frame(width: 2, height: 10)
                                    .offset(x: xPos)
                                
                                // Label
                                Text(String(format: "0:%02d", second))
                                    .font(.caption2)
                                    .foregroundStyle(.gray)
                                    .offset(x: xPos + 4, y: 12)
                                
                                // Minor Ticks (every 0.2s = 4 bars = 40pt)
                                ForEach(1..<5) { tick in
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.5))
                                        .frame(width: 1, height: 5)
                                        .offset(x: xPos + CGFloat(tick) * 40.0)
                                }
                            }
                        }
                        .frame(width: totalWidth, height: 30, alignment: .topLeading)
                    }
                    .frame(width: totalWidth, alignment: .leading)
                    .offset(x: centerOffset - currentX)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if !isDragging {
                                    isDragging = true
                                    voiceRecorder.pausePlayback()
                                    // Initialize scrubbingTime to current valid time
                                    scrubbingTime = voiceRecorder.currentTime
                                }
                                
                                // Calculate scrub based on drag translation
                                // translation / totalBarWidth gives number of bars dragged
                                // each bar is 0.05s (20Hz)
                                // Pixels per second = 20 * 10 = 200
                                let pixelsPerSecond = 20.0 * totalBarWidth
                                let dragSeconds = Double(-value.translation.width / pixelsPerSecond)
                                
                                scrubbingTime = max(0, min(duration, voiceRecorder.currentTime + dragSeconds))
                            }
                            .onEnded { value in
                                let totalBarWidth = barWidth + spacing
                                let pixelsPerSecond = 20.0 * totalBarWidth
                                let dragSeconds = Double(-value.translation.width / pixelsPerSecond)
                                let newTime = max(0, min(duration, voiceRecorder.currentTime + dragSeconds))
                                
                                voiceRecorder.seek(to: newTime)
                                voiceRecorder.startPlayback()
                                isDragging = false
                                scrubbingTime = 0
                            }
                    )
                }
                
                // Static Playhead
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2, height: 280) // Taller to cover ruler too
                    .offset(y: -15) // Adjust alignment
            }
            .frame(height: 280) // Adjusted total height
            .background(Color.black.opacity(0.3))
            
            Spacer()
            
            Button(action: {
                if voiceRecorder.isPlaying {
                    voiceRecorder.pausePlayback()
                } else {
                    voiceRecorder.startPlayback()
                }
            }) {
                Image(systemName: voiceRecorder.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundStyle(.red)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .alert("Delete Recording", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
                .tint(.white)
            Button("Delete", role: .destructive) {
                storage.deleteRecording(recording)
                dismiss()
            }
            .tint(.red)
        } message: {
            Text("Are you sure you want to delete \"\(getRecordingName())\"?")
        }
        .onAppear {
            voiceRecorder.startPlayback()
        }
        .onDisappear {
            voiceRecorder.stopPlayback()
        }
    }
    
    private func getRecordingName() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        let fullName = formatter.string(from: recording.date)
        return fullName.count > 20 ? String(fullName.prefix(20)) + "..." : fullName
    }
}

#Preview {
    let mockRecorder = VoiceRecorder()
    let mockStorage = RecordingStorage()
    let mockRecording = Recording(filename: "test.m4a", date: Date(), duration: 10.0, samples: [0.1, 0.3, 0.5, 0.8, 0.4, 0.2, 0.6, 0.9, 0.3])
    mockRecorder.audioSamples = [0.1, 0.3, 0.5, 0.8, 0.4, 0.2, 0.6, 0.9, 0.3]
    
    return PlaybackView(voiceRecorder: mockRecorder, storage: mockStorage, recording: mockRecording)
}
