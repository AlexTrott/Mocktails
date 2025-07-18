import Foundation

public final class Mocktail {
    private var mockResponses: [MockResponse]
    private var placeholders: [String: String] = [:]
    
    public init(mocksDirectoryURL: URL) throws {
        self.mockResponses = try Self.loadMockResponses(from: mocksDirectoryURL)
    }
    
    public static func start(withMocksAt directoryURL: URL, 
                           in configuration: URLSessionConfiguration = .default) throws -> Mocktail {
        let mocktail = try Mocktail(mocksDirectoryURL: directoryURL)
        MocktailURLProtocol.mocktail = mocktail
        configuration.protocolClasses = [MocktailURLProtocol.self] + (configuration.protocolClasses ?? [])
        return mocktail
    }
    
    public subscript(placeholder: String) -> String? {
        get { placeholders[placeholder] }
        set { placeholders[placeholder] = newValue }
    }
    
    func mockResponse(for request: URLRequest) -> MockResponse? {
        for i in 0..<mockResponses.count {
            if mockResponses[i].matches(request: request) {
                let response = mockResponses[i]
                mockResponses[i].advanceToNextResponse()
                return response
            }
        }
        return nil
    }
    
    func processPlaceholders(in text: String) -> String {
        var result = text
        for (key, value) in placeholders {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return result
    }
    
    private static func loadMockResponses(from directoryURL: URL) throws -> [MockResponse] {
        let fileManager = FileManager.default
        let tailFiles = try fileManager.contentsOfDirectory(at: directoryURL, 
                                                           includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "tail" }
        
        return try tailFiles.compactMap { fileURL in
            try MockResponse(contentsOf: fileURL)
        }
    }
}