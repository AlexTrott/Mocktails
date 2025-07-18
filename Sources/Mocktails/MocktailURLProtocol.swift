import Foundation

final class MocktailURLProtocol: URLProtocol {
    static weak var mocktail: Mocktail?
    
    override class func canInit(with request: URLRequest) -> Bool {
        return mocktail != nil
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        MocktailLogger.shared.info("📥 Incoming request: \(request.httpMethod ?? "UNKNOWN") \(request.url?.absoluteString ?? "NO_URL")")
        
        guard let mocktail = Self.mocktail,
              let mockResponse = mocktail.mockResponse(for: request) else {
            MocktailLogger.shared.error("❌ No mock response found for request: \(request.httpMethod ?? "UNKNOWN") \(request.url?.absoluteString ?? "NO_URL")")
            client?.urlProtocol(self, didFailWithError: MocktailError.networkError("No mock response found"))
            return
        }
        
        MocktailLogger.shared.info("✅ Found mock response for request: \(request.httpMethod ?? "UNKNOWN") \(request.url?.absoluteString ?? "NO_URL")")
        
        guard let url = request.url else {
            MocktailLogger.shared.error("❌ Invalid URL in request")
            client?.urlProtocol(self, didFailWithError: MocktailError.networkError("Invalid URL"))
            return
        }
        
        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: mockResponse.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: mockResponse.headers
        )
        
        guard let response = httpResponse else {
            MocktailLogger.shared.error("❌ Failed to create HTTP response")
            client?.urlProtocol(self, didFailWithError: MocktailError.networkError("Failed to create HTTP response"))
            return
        }
        
        MocktailLogger.shared.info("📤 Returning response: \(mockResponse.statusCode) for \(url.absoluteString)")
        
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        
        let processedBody: Data
        if let bodyString = String(data: mockResponse.body, encoding: .utf8) {
            let processedString = mocktail.processPlaceholders(in: bodyString)
            processedBody = processedString.data(using: .utf8) ?? mockResponse.body
        } else {
            processedBody = mockResponse.body
        }
        
        client?.urlProtocol(self, didLoad: processedBody)
        client?.urlProtocolDidFinishLoading(self)
        
        MocktailLogger.shared.info("✅ Successfully completed request for \(url.absoluteString)")
    }
    
    override func stopLoading() {
    }
}