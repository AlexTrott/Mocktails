# Mocktails 🍹

A modern Swift library for mocking HTTP responses during development and testing. Inspired by the original [objc-mocktail](https://github.com/puls/objc-mocktail) but built from the ground up with Swift-first design principles.

## Features

- 🎯 **Simple Setup**: Get started with just a few lines of code
- 📁 **File-based Mocks**: Define responses using `.tail` files
- 🔄 **Dynamic Placeholders**: Inject dynamic content using template variables
- 📱 **Cross-platform**: Works on iOS, macOS, tvOS, and watchOS
- ⚡ **Lightweight**: Minimal overhead with efficient request matching
- 🧪 **Test-friendly**: Perfect for unit tests and UI tests

## Installation

### Swift Package Manager

Add Mocktails to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/alextrott/Mocktails.git", from: "1.0.0")
]
```

Or add it through Xcode:
1. Go to File → Add Package Dependencies
2. Enter: `https://github.com/alextrott/Mocktails.git`

## Quick Start

### 1. Create Mock Files

Create `.tail` files to define your mock responses:

**users.tail**
```
GET
https://api\.example\.com/users
200
Content-Type: application/json

{
  "users": [
    {
      "id": 1,
      "name": "{{username}}",
      "email": "{{email}}"
    }
  ]
}
```

### 2. Setup Mocktails

```swift
import Mocktails

// Get the URL to your mocks directory
let mocksURL = Bundle.main.url(forResource: "Mocks", withExtension: nil)!

// Create a URL session configuration
let config = URLSessionConfiguration.default

// Start Mocktails
let mocktail = try Mocktails.start(withMocksAt: mocksURL, in: config)

// Set dynamic values
mocktail["username"] = "John Doe"
mocktail["email"] = "john@example.com"

// Use the configured session for requests
let session = URLSession(configuration: config)
```

### 3. Make Requests

```swift
let request = URLRequest(url: URL(string: "https://api.example.com/users")!)

session.dataTask(with: request) { data, response, error in
    // Receives the mocked response!
    print(String(data: data!, encoding: .utf8)!)
    // Output: {"users":[{"id":1,"name":"John Doe","email":"john@example.com"}]}
}.resume()
```

## File Format

Each `.tail` file follows this structure:

```
{HTTP_METHOD_REGEX}
{URL_REGEX}
{STATUS_CODE}
{HEADER_NAME}: {HEADER_VALUE}
{HEADER_NAME}: {HEADER_VALUE}
...
{EMPTY_LINE}
{RESPONSE_BODY}
```

### Examples

**Basic JSON Response**
```
GET
https://api\.example\.com/status
200
Content-Type: application/json

{"status": "ok"}
```

**With Custom Headers**
```
POST
https://api\.example\.com/login
201
Content-Type: application/json
Set-Cookie: session=abc123; HttpOnly

{"success": true, "token": "jwt_token_here"}
```

**Binary Data (Base64)**
```
GET
https://api\.example\.com/images/.*
200
Content-Type: image/png

base64:iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==
```

## Dynamic Placeholders

Use `{{placeholder}}` syntax in your response bodies:

```swift
mocktail["username"] = "Alice"
mocktail["userId"] = "123"
```

In your `.tail` file:
```json
{
  "user": {
    "id": "{{userId}}",
    "name": "{{username}}"
  }
}
```

## Advanced Usage

### Multiple Configurations

```swift
// Different configurations for different test scenarios
let devConfig = URLSessionConfiguration.default
let testConfig = URLSessionConfiguration.ephemeral

let devMocktail = try Mocktails.start(withMocksAt: devMocksURL, in: devConfig)
let testMocktail = try Mocktails.start(withMocksAt: testMocksURL, in: testConfig)
```

### Error Responses

```
POST
https://api\.example\.com/login
401
Content-Type: application/json

{"error": "Invalid credentials"}
```

### Regex Patterns

Use regex for flexible URL matching:

```
GET
https://api\.example\.com/users/\d+
200
Content-Type: application/json

{"id": "{{userId}}", "name": "User {{userId}}"}
```

## Testing

Mocktails works great with XCTest:

```swift
class NetworkTests: XCTestCase {
    var mocktail: Mocktails!
    var session: URLSession!
    
    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        let mocksURL = Bundle(for: type(of: self)).url(forResource: "TestMocks", withExtension: nil)!
        mocktail = try! Mocktails.start(withMocksAt: mocksURL, in: config)
        session = URLSession(configuration: config)
    }
    
    func testUserFetch() {
        mocktail["userId"] = "123"
        // ... test implementation
    }
}
```

## Performance

- **O(N) lookup time** where N is the number of mock files
- **Memory efficient**: Responses are loaded once at startup
- **Regex caching**: Compiled patterns are reused for better performance

## Limitations

- Mock files are loaded entirely into memory
- Request matching is performed sequentially
- Designed for development/testing, not production use

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see LICENSE file for details.

## Acknowledgments

Inspired by the original [objc-mocktail](https://github.com/puls/objc-mocktail) by Tobias Ottenweller.
