import Foundation

struct MockResponse {
    let methodPattern: NSRegularExpression
    let urlPattern: NSRegularExpression
    let statusCode: Int
    let headers: [String: String]
    let body: Data
    
    init(contentsOf fileURL: URL) throws {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        
        guard lines.count >= 3 else {
            throw MocktailError.invalidTailFile("File must have at least 3 lines")
        }
        
        self.methodPattern = try NSRegularExpression(pattern: lines[0], options: [.caseInsensitive])
        self.urlPattern = try NSRegularExpression(pattern: lines[1], options: [])
        
        guard let statusCode = Int(lines[2]) else {
            throw MocktailError.invalidTailFile("Invalid status code: \(lines[2])")
        }
        self.statusCode = statusCode
        
        var headers: [String: String] = [:]
        var bodyStartIndex = 3
        
        for i in 3..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
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
        
        self.headers = headers
        
        let bodyLines = Array(lines[bodyStartIndex...])
        let bodyString = bodyLines.joined(separator: "\n")
        
        if bodyString.hasPrefix("base64:") {
            let base64String = String(bodyString.dropFirst(7))
            guard let data = Data(base64Encoded: base64String) else {
                throw MocktailError.invalidTailFile("Invalid base64 data")
            }
            self.body = data
        } else {
            self.body = bodyString.data(using: .utf8) ?? Data()
        }
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