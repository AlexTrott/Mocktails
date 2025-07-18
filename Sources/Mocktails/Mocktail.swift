import Foundation

public final class Mocktail {
    private var mockResponses: [MockResponse]
    private var placeholders: [String: String] = [:]
    
    public init(mocksDirectoryURL: URL) throws {
        MocktailLogger.shared.info("🚀 Initializing Mocktail with directory: \(mocksDirectoryURL.path)")
        self.mockResponses = try Self.loadMockResponses(from: mocksDirectoryURL)
        MocktailLogger.shared.info("🚀 Mocktail initialized with \(mockResponses.count) mock responses")
    }
    
    public static func start(withMocksAt directoryURL: URL, 
                           in configuration: URLSessionConfiguration = .default,
                           logLevel: MocktailLogger.LogLevel = .info) throws -> Mocktail {
        MocktailLogger.shared.configure(logLevel: logLevel)
        MocktailLogger.shared.info("🚀 Starting Mocktail service with log level: \(logLevel.rawValue)")
        let mocktail = try Mocktail(mocksDirectoryURL: directoryURL)
        MocktailURLProtocol.mocktail = mocktail
        configuration.protocolClasses = [MocktailURLProtocol.self] + (configuration.protocolClasses ?? [])
        MocktailLogger.shared.info("🚀 Mocktail service started and configured")
        return mocktail
    }
    
    public subscript(placeholder: String) -> String? {
        get { placeholders[placeholder] }
        set { placeholders[placeholder] = newValue }
    }
    
    func mockResponse(for request: URLRequest) -> MockResponse? {
        let requestString = "\(request.httpMethod ?? "UNKNOWN") \(request.url?.absoluteString ?? "NO_URL")"
        MocktailLogger.shared.debug("🔍 Searching for mock response matching: \(requestString)")
        
        for i in 0..<mockResponses.count {
            MocktailLogger.shared.debug("🔍 Checking mock response \(i + 1)/\(mockResponses.count)")
            if mockResponses[i].matches(request: request) {
                let response = mockResponses[i]
                MocktailLogger.shared.info("✅ Found matching mock response \(i + 1)/\(mockResponses.count) for: \(requestString)")
                mockResponses[i].advanceToNextResponse()
                return response
            }
        }
        MocktailLogger.shared.notice("⚠️ No matching mock response found for: \(requestString)")
        return nil
    }
    
    func processPlaceholders(in text: String) -> String {
        var result = text
        let originalPlaceholderCount = placeholders.count
        MocktailLogger.shared.debug("🔧 Processing \(originalPlaceholderCount) placeholders in response body")
        
        for (key, value) in placeholders {
            let placeholder = "{{\(key)}}"
            if result.contains(placeholder) {
                MocktailLogger.shared.debug("🔧 Replacing placeholder '\(placeholder)' with '\(value)'")
                result = result.replacingOccurrences(of: placeholder, with: value)
            }
        }
        return result
    }
    
    private static func loadMockResponses(from directoryURL: URL) throws -> [MockResponse] {
        MocktailLogger.shared.info("📁 Loading mock responses from directory: \(directoryURL.path)")
        
        let fileManager = FileManager.default
        let tailFiles = try fileManager.contentsOfDirectory(at: directoryURL, 
                                                           includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "tail" }
        
        MocktailLogger.shared.info("📄 Found \(tailFiles.count) .tail files")
        
        return try tailFiles.compactMap { fileURL in
            MocktailLogger.shared.debug("📄 Loading mock response from: \(fileURL.lastPathComponent)")
            do {
                let mockResponse = try MockResponse(contentsOf: fileURL)
                MocktailLogger.shared.debug("✅ Successfully loaded mock response from: \(fileURL.lastPathComponent)")
                return mockResponse
            } catch {
                MocktailLogger.shared.error("❌ Failed to load mock response from \(fileURL.lastPathComponent): \(error)")
                throw error
            }
        }
    }
}