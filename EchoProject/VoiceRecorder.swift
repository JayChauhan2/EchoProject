import Foundation
import AVFoundation
import Combine

class VoiceRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    
    var audioRecorder: AVAudioRecorder?
    var audioPlayer: AVAudioPlayer?
    var timer: Timer?
    
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var audioSamples: [Float] = []
    @Published var currentAmplitude: Float = 0.0
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    
    private var currentRecordingFilename: String?
    private var recordingStartTime: Date?
    
    override init() {
        super.init()
    }
    
    func requestPermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { allowed in
            print("Permission allowed: \(allowed)")
        }
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    func startRecording() {
        stopPlayback()
        audioPlayer = nil
        
        // Generate unique filename
        let filename = "\(UUID().uuidString).m4a"
        currentRecordingFilename = filename
        recordingStartTime = Date()
        
        let audioFilename = getDocumentsDirectory().appendingPathComponent(filename)
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
            
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            isRecording = true
            audioSamples = []
            
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                self.audioRecorder?.updateMeters()
                // Normalize power (typically -160 to 0) to 0...1 range roughly
                let power = self.audioRecorder?.averagePower(forChannel: 0) ?? -160
                // Simple normalization: (power + 160) / 160
                // Use a tighter range for better visuals, e.g. -60 to 0
                let minDb: Float = -60.0
                let normalized = max(0.0, (power - minDb) / -minDb) + 0.01 // ensure non-zero
                
                self.currentAmplitude = normalized
                self.audioSamples.append(normalized)
            }
            
        } catch {
            print("Could not start recording: \(error)")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        timer?.invalidate()
        timer = nil
    }
    
    func getCurrentRecording() -> Recording? {
        guard let filename = currentRecordingFilename,
              let startTime = recordingStartTime else {
            return nil
        }
        
        let recordingDuration = Date().timeIntervalSince(startTime)
        return Recording(filename: filename, date: startTime, duration: recordingDuration, samples: audioSamples)
    }
    
    func loadRecording(_ recording: Recording) {
        stopPlayback()
        audioPlayer = nil
        currentRecordingFilename = recording.filename
        
        let audioFilename = getDocumentsDirectory().appendingPathComponent(recording.filename)
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioFilename)
            audioPlayer?.delegate = self
            audioPlayer?.volume = 1.0
            audioPlayer?.prepareToPlay()
            duration = audioPlayer?.duration ?? 0
            
            // Restore samples from recording
            audioSamples = recording.samples
        } catch {
            print("Failed to load recording: \(error)")
        }
    }
    
    func startPlayback() {
        guard let filename = currentRecordingFilename else {
            print("No recording filename available")
            return
        }
        
        let audioFilename = getDocumentsDirectory().appendingPathComponent(filename)
        
        do {
            if audioPlayer == nil {
                audioPlayer = try AVAudioPlayer(contentsOf: audioFilename)
                audioPlayer?.delegate = self
                audioPlayer?.volume = 1.0
                audioPlayer?.prepareToPlay()
                duration = audioPlayer?.duration ?? 0
            }
            
            audioPlayer?.play()
            isPlaying = true
            
            // Timer to update playback progress
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                if let player = self.audioPlayer {
                    self.currentTime = player.currentTime
                }
            }
        } catch {
            print("Playback failed: \(error)")
        }
    }
    
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }
    
    func pausePlayback() {
        audioPlayer?.pause()
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - AVAudioRecorderDelegate
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            stopRecording()
        }
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        timer?.invalidate()
        timer = nil
        isPlaying = false
        currentTime = duration // Ensure it shows complete
    }
}
