import Foundation
import Combine

class RecordingStorage: ObservableObject {
    @Published var recordings: [Recording] = []
    
    private let userDefaultsKey = "SavedRecordings"
    
    init() {
        loadRecordings()
    }
    
    func saveRecording(_ recording: Recording) {
        recordings.insert(recording, at: 0) // Add to beginning
        persistRecordings()
    }
    
    func deleteRecording(_ recording: Recording) {
        recordings.removeAll { $0.id == recording.id }
        
        // Delete audio file
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(recording.filename)
        try? FileManager.default.removeItem(at: fileURL)
        
        persistRecordings()
    }
    
    private func loadRecordings() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([Recording].self, from: data) else {
            recordings = []
            return
        }
        recordings = decoded
    }
    
    private func persistRecordings() {
        if let encoded = try? JSONEncoder().encode(recordings) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
}
