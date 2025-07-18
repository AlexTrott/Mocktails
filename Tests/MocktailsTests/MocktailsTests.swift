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
        
        // Test cycling through responses sequentially
        let expectedStatusCodes = [200, 200, 404, 200, 200] // Last one repeats
        var actualStatusCodes: [Int] = []
        var actualResponseBodies: [String] = []
        
        // Make requests sequentially to ensure order
        for i in 0..<5 {
            let expectation = XCTestExpectation(description: "Request \(i + 1)")
            
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
            
            wait(for: [expectation], timeout: 5.0)
        }
        
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
    
    func testNetworkDelayParsing() throws {
        let tailContent = """
        GET
        https://api\\.example\\.com/test
        200
        #networkDelay:0.5
        Content-Type: application/json
        
        {"message": "Delayed response"}
        """
        
        let tailFile = tempDirectory.appendingPathComponent("delay.tail")
        try tailContent.write(to: tailFile, atomically: true, encoding: .utf8)
        
        let mocktail = try Mocktail(mocksDirectoryURL: tempDirectory)
        let request = URLRequest(url: URL(string: "https://api.example.com/test")!)
        
        let mockResponse = mocktail.mockResponse(for: request)
        XCTAssertNotNil(mockResponse)
        XCTAssertEqual(mockResponse?.networkDelay, 0.5)
        XCTAssertEqual(mockResponse?.statusCode, 200)
        XCTAssertEqual(mockResponse?.headers["Content-Type"], "application/json")
    }
    
    func testNetworkDelayWithUrlSession() throws {
        let tailContent = """
        GET
        https://api\\.example\\.com/delayed
        200
        #networkDelay:0.2
        Content-Type: application/json
        
        {"message": "This response is delayed"}
        """
        
        let tailFile = tempDirectory.appendingPathComponent("delayed.tail")
        try tailContent.write(to: tailFile, atomically: true, encoding: .utf8)
        
        let configuration = URLSessionConfiguration.ephemeral
        let mocktail = try Mocktail.start(withMocksAt: tempDirectory, in: configuration)
        let session = URLSession(configuration: configuration)
        _ = mocktail // Suppress unused variable warning
        
        let expectation = XCTestExpectation(description: "Delayed network request")
        let request = URLRequest(url: URL(string: "https://api.example.com/delayed")!)
        
        let startTime = Date()
        
        session.dataTask(with: request) { data, response, error in
            let endTime = Date()
            let elapsedTime = endTime.timeIntervalSince(startTime)
            
            XCTAssertNil(error)
            XCTAssertNotNil(data)
            
            // Verify that the delay was applied (should be at least 0.2 seconds)
            XCTAssertGreaterThanOrEqual(elapsedTime, 0.2)
            
            if let httpResponse = response as? HTTPURLResponse {
                XCTAssertEqual(httpResponse.statusCode, 200)
            }
            
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                XCTAssertEqual(json["message"] as? String, "This response is delayed")
            }
            
            expectation.fulfill()
        }.resume()
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testMultipleRequestBlocksWithDifferentDelays() throws {
        let tailContent = """
        GET
        https://api\\.example\\.com/users
        200
        #networkDelay:0.1
        Content-Type: application/json
        
        {"users": [{"id": 1, "name": "Fast"}]}
        
        --
        
        200
        #networkDelay:0.3
        Content-Type: application/json
        
        {"users": [{"id": 2, "name": "Slow"}]}
        
        --
        
        404
        #networkDelay:0.0
        Content-Type: application/json
        
        """
        
        let tailFile = tempDirectory.appendingPathComponent("mixed_delays.tail")
        try tailContent.write(to: tailFile, atomically: true, encoding: .utf8)
        
        let configuration = URLSessionConfiguration.ephemeral
        let mocktail = try Mocktail.start(withMocksAt: tempDirectory, in: configuration)
        let session = URLSession(configuration: configuration)
        _ = mocktail // Suppress unused variable warning
        
        let url = URL(string: "https://api.example.com/users")!
        let request = URLRequest(url: url)
        
        // Test first request (0.1s delay)
        let firstExpectation = XCTestExpectation(description: "First delayed request")
        let firstStartTime = Date()
        
        session.dataTask(with: request) { data, response, error in
            let elapsedTime = Date().timeIntervalSince(firstStartTime)
            
            XCTAssertNil(error)
            XCTAssertGreaterThanOrEqual(elapsedTime, 0.1)
            
            if let httpResponse = response as? HTTPURLResponse {
                XCTAssertEqual(httpResponse.statusCode, 200)
            }
            
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let users = json["users"] as? [[String: Any]],
               let firstUser = users.first {
                XCTAssertEqual(firstUser["name"] as? String, "Fast")
            }
            
            firstExpectation.fulfill()
        }.resume()
        
        wait(for: [firstExpectation], timeout: 5.0)
        
        // Test second request (0.3s delay)
        let secondExpectation = XCTestExpectation(description: "Second delayed request")
        let secondStartTime = Date()
        
        session.dataTask(with: request) { data, response, error in
            let elapsedTime = Date().timeIntervalSince(secondStartTime)
            
            XCTAssertNil(error)
            XCTAssertGreaterThanOrEqual(elapsedTime, 0.3)
            
            if let httpResponse = response as? HTTPURLResponse {
                XCTAssertEqual(httpResponse.statusCode, 200)
            }
            
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let users = json["users"] as? [[String: Any]],
               let firstUser = users.first {
                XCTAssertEqual(firstUser["name"] as? String, "Slow")
            }
            
            secondExpectation.fulfill()
        }.resume()
        
        wait(for: [secondExpectation], timeout: 5.0)
        
        // Test third request (0.0s delay - immediate)
        let thirdExpectation = XCTestExpectation(description: "Third immediate request")
        let thirdStartTime = Date()
        
        session.dataTask(with: request) { data, response, error in
            let elapsedTime = Date().timeIntervalSince(thirdStartTime)
            
            XCTAssertNil(error)
            // Should be very fast (less than 0.1s)
            XCTAssertLessThan(elapsedTime, 0.1)
            
            if let httpResponse = response as? HTTPURLResponse {
                XCTAssertEqual(httpResponse.statusCode, 404)
            }
            
            thirdExpectation.fulfill()
        }.resume()
        
        wait(for: [thirdExpectation], timeout: 5.0)
    }
    
    func testNetworkDelayWithInvalidValue() throws {
        let tailContent = """
        GET
        https://api\\.example\\.com/test
        200
        #networkDelay:invalid
        Content-Type: application/json
        
        {"message": "Should default to no delay"}
        """
        
        let tailFile = tempDirectory.appendingPathComponent("invalid_delay.tail")
        try tailContent.write(to: tailFile, atomically: true, encoding: .utf8)
        
        let mocktail = try Mocktail(mocksDirectoryURL: tempDirectory)
        let request = URLRequest(url: URL(string: "https://api.example.com/test")!)
        
        let mockResponse = mocktail.mockResponse(for: request)
        XCTAssertNotNil(mockResponse)
        // Should default to 0.0 when invalid delay is provided
        XCTAssertEqual(mockResponse?.networkDelay, 0.0)
        XCTAssertEqual(mockResponse?.statusCode, 200)
    }
    
    func testNetworkDelayWithZeroDelay() throws {
        let tailContent = """
        GET
        https://api\\.example\\.com/test
        200
        #networkDelay:0.0
        Content-Type: application/json
        
        {"message": "Immediate response"}
        """
        
        let tailFile = tempDirectory.appendingPathComponent("zero_delay.tail")
        try tailContent.write(to: tailFile, atomically: true, encoding: .utf8)
        
        let configuration = URLSessionConfiguration.ephemeral
        let mocktail = try Mocktail.start(withMocksAt: tempDirectory, in: configuration)
        let session = URLSession(configuration: configuration)
        _ = mocktail // Suppress unused variable warning
        
        let expectation = XCTestExpectation(description: "Zero delay request")
        let request = URLRequest(url: URL(string: "https://api.example.com/test")!)
        
        let startTime = Date()
        
        session.dataTask(with: request) { data, response, error in
            let endTime = Date()
            let elapsedTime = endTime.timeIntervalSince(startTime)
            
            XCTAssertNil(error)
            XCTAssertNotNil(data)
            
            // Should be very fast (less than 0.1s)
            XCTAssertLessThan(elapsedTime, 0.1)
            
            if let httpResponse = response as? HTTPURLResponse {
                XCTAssertEqual(httpResponse.statusCode, 200)
            }
            
            expectation.fulfill()
        }.resume()
        
        wait(for: [expectation], timeout: 5.0)
    }
}
