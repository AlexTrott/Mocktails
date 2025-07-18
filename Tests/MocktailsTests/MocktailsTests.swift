import XCTest
@testable import Mocktails

final class MocktailsTests: XCTestCase {
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    func testMocktailInitialization() throws {
        let tailContent = """
        GET
        https://api\\.example\\.com/test
        200
        Content-Type: application/json
        
        {"message": "Hello World"}
        """
        
        let tailFile = tempDirectory.appendingPathComponent("test.tail")
        try tailContent.write(to: tailFile, atomically: true, encoding: .utf8)
        
        let mocktail = try Mocktail(mocksDirectoryURL: tempDirectory)
        XCTAssertNotNil(mocktail)
    }
    
    func testPlaceholderSubstitution() throws {
        let tailContent = """
        GET
        https://api\\.example\\.com/users
        200
        Content-Type: application/json
        
        {"name": "{{username}}", "id": {{userId}}}
        """
        
        let tailFile = tempDirectory.appendingPathComponent("users.tail")
        try tailContent.write(to: tailFile, atomically: true, encoding: .utf8)
        
        let mocktail = try Mocktail(mocksDirectoryURL: tempDirectory)
        mocktail["username"] = "John Doe"
        mocktail["userId"] = "123"
        
        let result = mocktail.processPlaceholders(in: "Hello {{username}}, your ID is {{userId}}")
        XCTAssertEqual(result, "Hello John Doe, your ID is 123")
    }
    
    func testMockResponseMatching() throws {
        let tailContent = """
        POST
        https://api\\.example\\.com/login
        201
        Content-Type: application/json
        
        {"success": true}
        """
        
        let tailFile = tempDirectory.appendingPathComponent("login.tail")
        try tailContent.write(to: tailFile, atomically: true, encoding: .utf8)
        
        let mocktail = try Mocktail(mocksDirectoryURL: tempDirectory)
        
        var request = URLRequest(url: URL(string: "https://api.example.com/login")!)
        request.httpMethod = "POST"
        
        let mockResponse = mocktail.mockResponse(for: request)
        XCTAssertNotNil(mockResponse)
        XCTAssertEqual(mockResponse?.statusCode, 201)
    }
    
    func testBase64Response() throws {
        let tailContent = """
        GET
        https://api\\.example\\.com/image
        200
        Content-Type: image/png
        
        base64:iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==
        """
        
        let tailFile = tempDirectory.appendingPathComponent("image.tail")
        try tailContent.write(to: tailFile, atomically: true, encoding: .utf8)
        
        let mocktail = try Mocktail(mocksDirectoryURL: tempDirectory)
        
        let request = URLRequest(url: URL(string: "https://api.example.com/image")!)
        let mockResponse = mocktail.mockResponse(for: request)
        
        XCTAssertNotNil(mockResponse)
        XCTAssertEqual(mockResponse?.headers["Content-Type"], "image/png")
        XCTAssertGreaterThan(mockResponse?.body.count ?? 0, 0)
    }
    
    func testInvalidTailFile() {
        let invalidContent = "GET\n"
        let tailFile = tempDirectory.appendingPathComponent("invalid.tail")
        
        do {
            try invalidContent.write(to: tailFile, atomically: true, encoding: .utf8)
            _ = try Mocktail(mocksDirectoryURL: tempDirectory)
            XCTFail("Should have thrown an error for invalid tail file")
        } catch {
            XCTAssertTrue(error is MocktailError)
        }
    }
    
    func testURLSessionIntegration() throws {
        let tailContent = """
        GET
        https://api\\.example\\.com/test
        200
        Content-Type: application/json
        
        {"message": "Mocked response"}
        """
        
        let tailFile = tempDirectory.appendingPathComponent("test.tail")
        try tailContent.write(to: tailFile, atomically: true, encoding: .utf8)
        
        let configuration = URLSessionConfiguration.ephemeral
        let mocktail = try Mocktail.start(withMocksAt: tempDirectory, in: configuration)
        let session = URLSession(configuration: configuration)
        
        mocktail["placeholder"] = "test"
        
        let expectation = XCTestExpectation(description: "Network request")
        let request = URLRequest(url: URL(string: "https://api.example.com/test")!)
        
        session.dataTask(with: request) { data, response, error in
            XCTAssertNil(error)
            XCTAssertNotNil(data)
            
            if let httpResponse = response as? HTTPURLResponse {
                XCTAssertEqual(httpResponse.statusCode, 200)
                XCTAssertEqual(httpResponse.allHeaderFields["Content-Type"] as? String, "application/json")
            }
            
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                XCTAssertEqual(json["message"] as? String, "Mocked response")
            }
            
            expectation.fulfill()
        }.resume()
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testMultipleRequestBlocks() throws {
        let tailContent = """
        GET
        https://api\\.example\\.com/users
        200
        Content-Type: application/json
        
        {"users": [{"id": 1, "name": "{{username1}}"}]}
        
        --
        
        200
        Content-Type: application/json
        
        {"users": [{"id": 2, "name": "{{username2}}"}]}
        
        --
        
        404
        Content-Type: application/json
        
        --
        
        200
        Content-Type: application/json
        
        {"users": [{"id": 3, "name": "{{username3}}"}]}
        """
        
        let tailFile = tempDirectory.appendingPathComponent("multiple.tail")
        try tailContent.write(to: tailFile, atomically: true, encoding: .utf8)
        
        let configuration = URLSessionConfiguration.ephemeral
        let mocktail = try Mocktail.start(withMocksAt: tempDirectory, in: configuration)
        let session = URLSession(configuration: configuration)
        
        mocktail["username1"] = "Alice"
        mocktail["username2"] = "Bob"
        mocktail["username3"] = "Charlie"
        
        let url = URL(string: "https://api.example.com/users")!
        let request = URLRequest(url: url)
        
        // Test cycling through responses
        let expectations = [
            XCTestExpectation(description: "First request"),
            XCTestExpectation(description: "Second request"),
            XCTestExpectation(description: "Third request"),
            XCTestExpectation(description: "Fourth request"),
            XCTestExpectation(description: "Fifth request")
        ]
        
        let expectedStatusCodes = [200, 200, 404, 200, 200] // Last one repeats
        var actualStatusCodes: [Int] = []
        var actualResponseBodies: [String] = []
        
        for (index, expectation) in expectations.enumerated() {
            session.dataTask(with: request) { data, response, error in
                XCTAssertNil(error)
                
                if let httpResponse = response as? HTTPURLResponse {
                    actualStatusCodes.append(httpResponse.statusCode)
                }
                
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    actualResponseBodies.append(responseString)
                }
                
                expectation.fulfill()
            }.resume()
        }
        
        wait(for: expectations, timeout: 5.0)
        
        // Verify the cycling behavior
        XCTAssertEqual(actualStatusCodes, expectedStatusCodes)
        
        // Verify first response contains Alice
        XCTAssertTrue(actualResponseBodies[0].contains("Alice"))
        
        // Verify second response contains Bob
        XCTAssertTrue(actualResponseBodies[1].contains("Bob"))
        
        // Verify third response is empty (404)
        XCTAssertTrue(actualResponseBodies[2].isEmpty)
        
        // Verify fourth response contains Charlie
        XCTAssertTrue(actualResponseBodies[3].contains("Charlie"))
        
        // Verify fifth response also contains Charlie (repeats last)
        XCTAssertTrue(actualResponseBodies[4].contains("Charlie"))
    }
}