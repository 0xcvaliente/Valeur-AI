import AppKit
import Foundation
import UniformTypeIdentifiers

enum RemoteImageDownloadError: LocalizedError {
    case invalidURL
    case invalidResponse
    case responseTooLarge(Int)
    case unsupportedImage

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Enter a valid http or https image URL."
        case .invalidResponse:
            return "Could not download the image from that URL."
        case .responseTooLarge:
            return "Attachment exceeds the 20 MB limit."
        case .unsupportedImage:
            return "That URL did not return a supported image."
        }
    }
}

struct RemoteImageDownloadResult {
    let data: Data
    let response: HTTPURLResponse
}

enum RemoteImageSupport {
    nonisolated static let maximumImageBytes = 20 * 1024 * 1024

    static func normalizedHTTPURL(from rawValue: String?) -> URL? {
        let trimmed = (rawValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host?.isEmpty == false else {
            return nil
        }
        return url
    }

    static func downloadImage(from url: URL, maxBytes: Int = maximumImageBytes) async throws -> RemoteImageDownloadResult {
        guard let normalizedURL = normalizedHTTPURL(from: url.absoluteString) else {
            throw RemoteImageDownloadError.invalidURL
        }

        var request = URLRequest(url: normalizedURL)
        request.timeoutInterval = 120

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw RemoteImageDownloadError.invalidResponse
        }

        if response.expectedContentLength > Int64(maxBytes) {
            throw RemoteImageDownloadError.responseTooLarge(maxBytes)
        }

        if let mimeType = httpResponse.mimeType,
           let contentType = UTType(mimeType: mimeType),
           !contentType.conforms(to: .image) {
            throw RemoteImageDownloadError.unsupportedImage
        }

        var data = Data()
        data.reserveCapacity(min(maxBytes, max(Int(response.expectedContentLength), 0)))

        for try await byte in bytes {
            data.append(byte)
            if data.count > maxBytes {
                throw RemoteImageDownloadError.responseTooLarge(maxBytes)
            }
        }

        guard NSImage(data: data) != nil else {
            throw RemoteImageDownloadError.unsupportedImage
        }

        return RemoteImageDownloadResult(data: data, response: httpResponse)
    }
}
