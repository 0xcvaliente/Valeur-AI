import Foundation

enum SecureFileAccess {
    static func data(from url: URL) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            return try Data(contentsOf: url)
        }.value
    }

    static func text(
        from url: URL,
        encodings: [String.Encoding] = [.utf8, .unicode, .utf16, .ascii, .isoLatin1]
    ) async throws -> String? {
        let data = try await data(from: url)
        for encoding in encodings {
            if let text = String(data: data, encoding: encoding) {
                return text
            }
        }
        return nil
    }
}
