import Foundation

enum CommunicationState: String, Codable {
    case confident = "Confident"
    case neutral = "Neutral"
    case hesitant = "Hesitant"
    case unclear = "Unclear"
}

struct AudioAnalysisResult: Codable {
    let speechRate: Double // Words per minute
    let pauseFrequency: Double // Pauses per minute
    let volumeStability: Double // Variance in volume (0.0 - 1.0, where 1.0 is stable)
    let communicationState: CommunicationState
    let transcription: String
    let confidenceScore: Double // 0.0 - 1.0
}
