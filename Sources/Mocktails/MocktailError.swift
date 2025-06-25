import Foundation

public enum MocktailError: Error, LocalizedError {
    case invalidTailFile(String)
    case fileNotFound(String)
    case networkError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidTailFile(let message):
            return "Invalid .tail file: \(message)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}