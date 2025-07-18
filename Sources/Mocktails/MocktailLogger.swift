import Foundation
import os.log

public final class MocktailLogger {
    public enum LogLevel: String, CaseIterable {
        case debug = "debug"
        case info = "info"
        case notice = "notice"
        case error = "error"
        case fault = "fault"
        
        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .notice: return .default
            case .error: return .error
            case .fault: return .fault
            }
        }
    }
    
    private let subsystem = "com.mocktails"
    private let category = "network"
    private let osLog: OSLog
    private let logLevel: LogLevel
    
    public static var shared: MocktailLogger = MocktailLogger()
    
    public init(logLevel: LogLevel = .info) {
        self.logLevel = logLevel
        self.osLog = OSLog(subsystem: subsystem, category: category)
    }
    
    public func configure(logLevel: LogLevel) {
        MocktailLogger.shared = MocktailLogger(logLevel: logLevel)
    }
    
    private func shouldLog(level: LogLevel) -> Bool {
        let levels: [LogLevel] = [.debug, .info, .notice, .error, .fault]
        guard let currentIndex = levels.firstIndex(of: logLevel),
              let requestedIndex = levels.firstIndex(of: level) else {
            return false
        }
        return requestedIndex >= currentIndex
    }
    
    public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, message: message, file: file, function: function, line: line)
    }
    
    public func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, message: message, file: file, function: function, line: line)
    }
    
    public func notice(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .notice, message: message, file: file, function: function, line: line)
    }
    
    public func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .error, message: message, file: file, function: function, line: line)
    }
    
    public func fault(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .fault, message: message, file: file, function: function, line: line)
    }
    
    private func log(level: LogLevel, message: String, file: String, function: String, line: Int) {
        guard shouldLog(level: level) else { return }
        
        let fileName = (file as NSString).lastPathComponent
        let formattedMessage = "[\(fileName):\(line)] \(function) - \(message)"
        
        os_log("%{public}@", log: osLog, type: level.osLogType, formattedMessage)
    }
}