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
        guard let mocktail = Self.mocktail,
              let mockResponse = mocktail.mockResponse(for: request) else {
            client?.urlProtocol(self, didFailWithError: MocktailError.networkError("No mock response found"))
            return
        }
        
        guard let url = request.url else {
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
            client?.urlProtocol(self, didFailWithError: MocktailError.networkError("Failed to create HTTP response"))
            return
        }
        
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
    }
    
    override func stopLoading() {
    }
}