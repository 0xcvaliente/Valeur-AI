import Foundation

enum SSEParserError: Error, LocalizedError {
    case lineTooLong
    case tooManyBufferedLines

    var errorDescription: String? {
        switch self {
        case .lineTooLong:
            return "SSE stream line exceeded maximum allowed length."
        case .tooManyBufferedLines:
            return "SSE stream event exceeded maximum allowed line count."
        }
    }
}

enum SSEEvent {
    case message(event: String?, data: String)
}

struct SSEParser {
    private static let maxLineBytes = 1 * 1024 * 1024
    private static let maxBufferLines = 1_000

    static func events(from bytes: URLSession.AsyncBytes) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var buffer: [String] = []
                    var lineData = Data()
                    for try await byte in bytes {
                        if byte == 10 { // \n
                            if lineData.last == 13 { // \r
                                lineData.removeLast()
                            }
                            let currentLine = String(decoding: lineData, as: UTF8.self)
                            lineData.removeAll(keepingCapacity: true)

                            if currentLine.isEmpty {
                                if let event = makeEvent(from: buffer) {
                                    continuation.yield(event)
                                }
                                buffer.removeAll(keepingCapacity: true)
                            } else {
                                buffer.append(currentLine)
                                if buffer.count > maxBufferLines {
                                    throw SSEParserError.tooManyBufferedLines
                                }
                            }
                        } else {
                            lineData.append(byte)
                            if lineData.count > maxLineBytes {
                                throw SSEParserError.lineTooLong
                            }
                        }
                    }

                    if !lineData.isEmpty {
                        let currentLine = String(decoding: lineData, as: UTF8.self)
                        buffer.append(currentLine)
                    }
                    if let event = makeEvent(from: buffer) {
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private static func makeEvent(from lines: [String]) -> SSEEvent? {
        guard !lines.isEmpty else { return nil }
        var eventName: String?
        var dataParts: [String] = []

        for line in lines {
            if line.hasPrefix("event:") {
                eventName = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                dataParts.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
            }
        }

        if eventName == nil && dataParts.isEmpty {
            return nil
        }

        return .message(event: eventName, data: dataParts.joined(separator: "\n"))
    }
}
