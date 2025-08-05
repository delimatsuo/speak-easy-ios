import Foundation

struct TranscriptionResult: Codable {
    let text: String
    let confidence: Float
    let segments: [TranscriptionSegment]
    let alternatives: [AlternativeTranscription]
    let isFinal: Bool
    let timestamp: Date
    let duration: TimeInterval
}

struct TranscriptionSegment: Codable {
    let substring: String
    let substringRange: NSRange
    let timestamp: TimeInterval
    let duration: TimeInterval
    let confidence: Float
    let alternativeSubstrings: [String]
}

struct AlternativeTranscription: Codable {
    let text: String
    let confidence: Float
    let likelihood: Float
}