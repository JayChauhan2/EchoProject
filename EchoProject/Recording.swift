import Foundation

struct Recording: Codable, Identifiable {
    let id: UUID
    let filename: String
    let date: Date
    let duration: TimeInterval
    
    init(id: UUID = UUID(), filename: String, date: Date, duration: TimeInterval) {
        self.id = id
        self.filename = filename
        self.date = date
        self.duration = duration
    }
}
