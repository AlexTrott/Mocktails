import Foundation

struct MockResponse {
    let methodPattern: NSRegularExpression
    let urlPattern: NSRegularExpression
    private let responses: [ResponseBlock]
    private var currentIndex: Int = 0
    
    private struct ResponseBlock {
        let statusCode: Int
        let headers: [String: String]
        let body: Data
    }
    
    var statusCode: Int {
        return responses[currentIndex].statusCode
    }
    
    var headers: [String: String] {
        return responses[currentIndex].headers
    }
    
    var body: Data {
        return responses[currentIndex].body
    }
    
    mutating func advanceToNextResponse() {
        if currentIndex < responses.count - 1 {
            currentIndex += 1
        }
        // If we're at the last response, stay there (return last request constantly)
    }
    
    init(contentsOf fileURL: URL) throws {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        
        guard lines.count >= 3 else {
            throw MocktailError.invalidTailFile("File must have at least 3 lines")
        }
        
        self.methodPattern = try NSRegularExpression(pattern: lines[0], options: [.caseInsensitive])
        self.urlPattern = try NSRegularExpression(pattern: lines[1], options: [])
        
        // Split content into blocks by "--"
        let contentBlocks = content.components(separatedBy: "\n--\n")
        var responseBlocks: [ResponseBlock] = []
        
        for (blockIndex, block) in contentBlocks.enumerated() {
            let blockLines = block.components(separatedBy: .newlines)
            
            // For first block, skip method and URL lines
            let startLineIndex = blockIndex == 0 ? 2 : 0
            
            guard blockLines.count > startLineIndex else {
                continue // Skip empty blocks
            }
            
            // Find the first non-empty line for status code
            var statusCodeLineIndex = startLineIndex
            while statusCodeLineIndex < blockLines.count && blockLines[statusCodeLineIndex].trimmingCharacters(in: .whitespaces).isEmpty {
                statusCodeLineIndex += 1
            }
            
            guard statusCodeLineIndex < blockLines.count else {
                continue // Skip blocks with no status code
            }
            
            guard let statusCode = Int(blockLines[statusCodeLineIndex].trimmingCharacters(in: .whitespaces)) else {
                throw MocktailError.invalidTailFile("Invalid status code: \(blockLines[statusCodeLineIndex])")
            }
            
            var headers: [String: String] = [:]
            var bodyStartIndex = statusCodeLineIndex + 1
            
            for i in (statusCodeLineIndex + 1)..<blockLines.count {
                let line = blockLines[i].trimmingCharacters(in: .whitespaces)
                if line.isEmpty {
                    bodyStartIndex = i + 1
                    break
                }
                
                let components = line.components(separatedBy: ": ")
                if components.count >= 2 {
                    let key = components[0]
                    let value = components.dropFirst().joined(separator: ": ")
                    headers[key] = value
                }
            }
            
            let bodyLines = Array(blockLines[bodyStartIndex...])
            let bodyString = bodyLines.joined(separator: "\n")
            
            let body: Data
            if bodyString.hasPrefix("base64:") {
                let base64String = String(bodyString.dropFirst(7))
                guard let data = Data(base64Encoded: base64String) else {
                    throw MocktailError.invalidTailFile("Invalid base64 data")
                }
                body = data
            } else {
                body = bodyString.data(using: .utf8) ?? Data()
            }
            
            responseBlocks.append(ResponseBlock(statusCode: statusCode, headers: headers, body: body))
        }
        
        guard !responseBlocks.isEmpty else {
            throw MocktailError.invalidTailFile("No valid response blocks found")
        }
        
        self.responses = responseBlocks
    }
    
    func matches(request: URLRequest) -> Bool {
        guard let httpMethod = request.httpMethod,
              let url = request.url?.absoluteString else {
            return false
        }
        
        let methodRange = NSRange(location: 0, length: httpMethod.count)
        let urlRange = NSRange(location: 0, length: url.count)
        
        return methodPattern.firstMatch(in: httpMethod, options: [], range: methodRange) != nil &&
               urlPattern.firstMatch(in: url, options: [], range: urlRange) != nil
    }
}