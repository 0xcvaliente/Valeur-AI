import Foundation

enum SecureFileAccessError: LocalizedError {
    case fileTooLarge(Int)

    var errorDescription: String? {
        switch self {
        case .fileTooLarge:
            return "Selected file exceeds the 20 MB limit."
        }
    }
}

enum SecureFileAccess {
    nonisolated static let maximumImportBytes = 20 * 1024 * 1024

    static func data(from url: URL, maxBytes: Int = maximumImportBytes) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            if let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
               fileSize > maxBytes {
                throw SecureFileAccessError.fileTooLarge(maxBytes)
            }

            let data = try Data(contentsOf: url)
            if data.count > maxBytes {
                throw SecureFileAccessError.fileTooLarge(maxBytes)
            }
            return data
        }.value
    }

    static func text(
        from url: URL,
        encodings: [String.Encoding] = [.utf8, .unicode, .utf16, .ascii, .isoLatin1],
        maxBytes: Int = maximumImportBytes
    ) async throws -> String? {
        let data = try await data(from: url, maxBytes: maxBytes)
        for encoding in encodings {
            if let text = String(data: data, encoding: encoding) {
                return text
            }
        }
        return nil
    }
}
