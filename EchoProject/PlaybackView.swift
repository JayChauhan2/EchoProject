import SwiftUI
import AVFoundation

struct PlaybackView: View {
    @ObservedObject var voiceRecorder: VoiceRecorder
    
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
                    
                    HStack(spacing: spacing) {
                        ForEach(voiceRecorder.audioSamples.indices, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.red)
                                // Boost amplitude to fill height: * 400. Clamp to max 250.
                                .frame(width: barWidth, height: min(250, max(4, CGFloat(voiceRecorder.audioSamples[index]) * 400)))
                        }
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
                                // each bar is 0.1s
                                // We need to relate pixel movement to time duration
                                // Pixels per second = (10 samples/sec) * totalBarWidth
                                let pixelsPerSecond = 10.0 * totalBarWidth
                                let dragSeconds = Double(-value.translation.width / pixelsPerSecond)
                                
                                scrubbingTime = max(0, min(duration, voiceRecorder.currentTime + dragSeconds))
                            }
                            .onEnded { value in
                                let totalBarWidth = barWidth + spacing
                                let pixelsPerSecond = 10.0 * totalBarWidth
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
                    .frame(width: 2, height: 250)
            }
            .frame(height: 250)
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
        .onAppear {
            voiceRecorder.startPlayback()
        }
    }
}

#Preview {
    let mockRecorder = VoiceRecorder()
    mockRecorder.audioSamples = [0.1, 0.3, 0.5, 0.8, 0.4, 0.2, 0.6, 0.9, 0.3]
    return PlaybackView(voiceRecorder: mockRecorder)
}
