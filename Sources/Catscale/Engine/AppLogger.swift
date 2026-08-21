import Foundation

public struct LogEntry: Identifiable, Sendable {
    public let id: UUID = UUID()
    public let timestamp: Date
    public let message: String
    public let level: LogLevel

    public enum LogLevel: String, Sendable {
        case info = "INFO"
        case debug = "DEBUG"
        case warning = "WARN"
        case error = "ERROR"
    }

    public init(timestamp: Date = Date(), message: String, level: LogLevel = .info) {
        self.timestamp = timestamp
        self.message = message
        self.level = level
    }
}

@Observable
public final class AppLogger: @unchecked Sendable {

    public static let shared = AppLogger()

    @MainActor public var entries: [LogEntry] = []
    @MainActor public var logCount: Int = 0

    private let lock = NSLock()
    private var logFileURL: URL?
    private var logFileHandle: FileHandle?
    private let dateFormatter: DateFormatter

    private init() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        self.dateFormatter = formatter

        setupLogFile()
    }

    /// Setup and initialize Documents/catscale.log
    private func setupLogFile() {
        lock.lock()
        defer { lock.unlock() }

        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let fileURL = documentsURL.appendingPathComponent("catscale.log")
        self.logFileURL = fileURL

        // Create fresh log file on launch (inter-app launches cleared)
        let initialHeader = "=== Catscale Session Started at \(dateFormatter.string(from: Date())) ===\n"
        if let data = initialHeader.data(using: .utf8) {
            try? data.write(to: fileURL, options: .atomic)
        }

        self.logFileHandle = try? FileHandle(forWritingTo: fileURL)
        self.logFileHandle?.seekToEndOfFile()
    }

    /// Log a message from any thread/actor and immediately flush to disk if logging is enabled
    public func log(_ message: String, level: LogEntry.LogLevel = .info, isEnabled: Bool) {
        guard isEnabled else { return }

        let now = Date()
        let entry = LogEntry(timestamp: now, message: message, level: level)

        lock.lock()
        let line = "[\(dateFormatter.string(from: now))] [\(level.rawValue)] \(message)\n"
        if let data = line.data(using: .utf8) {
            logFileHandle?.write(data)
            try? logFileHandle?.synchronize()
        }
        lock.unlock()

        Task { @MainActor in
            self.entries.append(entry)
            self.logCount = self.entries.count
        }
    }

    /// Clear in-memory entries and reset catscale.log
    @MainActor
    public func clear() {
        entries.removeAll()
        logCount = 0
        lock.lock()
        try? logFileHandle?.close()
        lock.unlock()
        setupLogFile()
    }

    /// Formatted log text for sharing / copying
    @MainActor
    public var formattedText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return entries.map { entry in
            "[\(formatter.string(from: entry.timestamp))] [\(entry.level.rawValue)] \(entry.message)"
        }.joined(separator: "\n")
    }
}
