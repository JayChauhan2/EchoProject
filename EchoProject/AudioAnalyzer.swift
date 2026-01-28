import Foundation
import Speech
import AVFoundation

class AudioAnalyzer: NSObject {
    
    // MARK: - Analysis Methods
    
    func analyze(url: URL) async throws -> AudioAnalysisResult {
        // 1. Transcription & Timing (Offline)
        let (transcription, wordTimings, speechRate, pauseFreq) = try await analyzeSpeech(url: url)
        
        // 2. Audio Signal Analysis
        let (volumeStability, _) = try analyzeAudioSignal(url: url)
        
        // 3. Heuristic Inference
        let state = inferCommunicationState(
            speechRate: speechRate,
            pauseFrequency: pauseFreq,
            volumeStability: volumeStability,
            wordCount: wordTimings.count
        )
        
        // Calculate a simple confidence score based on the state
        let confidenceScore: Double
        switch state {
        case .confident: confidenceScore = 0.9
        case .neutral: confidenceScore = 0.7
        case .hesitant: confidenceScore = 0.4
        case .unclear: confidenceScore = 0.2
        }
        
        return AudioAnalysisResult(
            speechRate: speechRate,
            pauseFrequency: pauseFreq,
            volumeStability: volumeStability,
            communicationState: state,
            transcription: transcription,
            confidenceScore: confidenceScore
        )
    }
    
    // MARK: - Private Helpers
    
    private func analyzeSpeech(url: URL) async throws -> (String, [SFTranscriptionSegment], Double, Double) {
        return try await withCheckedThrowingContinuation { continuation in
            let recognizer = SFSpeechRecognizer()
            
            // CRITICAL: Ensure offline capability
            if recognizer?.isAvailable == false {
                continuation.resume(throwing: NSError(domain: "AudioAnalyzer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available"]))
                return
            }
            
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = false
            request.requiresOnDeviceRecognition = true // Force offline recognition
            
            recognizer?.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let result = result, result.isFinal else { return }
                
                let transcription = result.bestTranscription.formattedString
                let segments = result.bestTranscription.segments
                let duration = segments.last?.timestamp ?? 0 + (segments.last?.duration ?? 0)
                
                // Calculate Speech Rate (WPM)
                // Avoid division by zero
                let durationInMinutes = max(duration / 60.0, 0.01)
                let wpm = Double(segments.count) / durationInMinutes
                
                // Calculate Pause Frequency
                // A "pause" is a significant gap between segments. Let's say > 0.5s
                var pauseCount = 0
                for i in 0..<segments.count - 1 {
                    let endCurrent = segments[i].timestamp + segments[i].duration
                    let startNext = segments[i+1].timestamp
                    if startNext - endCurrent > 0.5 {
                        pauseCount += 1
                    }
                }
                let pausesPerMinute = Double(pauseCount) / durationInMinutes
                
                continuation.resume(returning: (transcription, segments, wpm, pausesPerMinute))
            }
        }
    }
    
    private func analyzeAudioSignal(url: URL) throws -> (Double, Double) {
        let file = try AVAudioFile(forReading: url)
        
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: file.fileFormat.sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)) else {
            return (0, 0)
        }
        
        try file.read(into: buffer)
        
        guard let channelData = buffer.floatChannelData?[0] else { return (0, 0) }
        let frames = Int(buffer.frameLength)
        
        // Calculate RMS in chunks to see stability
        let chunkSize = 4096 // arbitrary
        var rmsValues: [Float] = []
        
        for i in stride(from: 0, to: frames, by: chunkSize) {
            let end = min(i + chunkSize, frames)
            let length = end - i
            var sum: Float = 0
            for j in 0..<length {
                let sample = channelData[i + j]
                sum += sample * sample
            }
            let rms = sqrt(sum / Float(length))
            rmsValues.append(rms)
        }
        
        // Calculate Variance of RMS - Lower variance means more stable volume
        let meanRMS = rmsValues.reduce(0, +) / Float(rmsValues.count)
        let variance = rmsValues.map { pow($0 - meanRMS, 2) }.reduce(0, +) / Float(rmsValues.count)
        
        // Normalize stability: 1.0 is stable, 0.0 is unstable
        // Variance depends on volume, but let's do a simple inverse mapping
        // A high variance might be 0.01 for speech?
        // Let's just return raw variance for now, or invert it carefully?
        // Better yet: "Stability" = 1 / (1 + variance * 1000)
        let stability = 1.0 / (1.0 + Double(variance) * 1000.0)
        
        return (stability, Double(meanRMS))
    }
    
    private func inferCommunicationState(speechRate: Double, pauseFrequency: Double, volumeStability: Double, wordCount: Int) -> CommunicationState {
        // Heuristics
        
        // Too fast or too slow?
        // Normal conversation: 120-150 wpm.
        // Presentations often slower: 100-120.
        
        if wordCount < 5 {
            return .unclear // Too short
        }
        
        let isSteady = volumeStability > 0.6
        let isFluid = pauseFrequency < 8.0 // Less than 8 significant pauses per minute
        let properPace = speechRate > 100 && speechRate < 160
        
        if isSteady && isFluid && properPace {
            return .confident
        }
        
        if pauseFrequency > 15 {
            return .hesitant
        }
        
        if speechRate < 80 || speechRate > 200 {
            // Too slow or too fast often indicates nervousness or lack of clarity
            return .unclear
        }
        
        return .neutral
    }
}
