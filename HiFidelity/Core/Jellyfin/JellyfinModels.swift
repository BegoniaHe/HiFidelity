import Foundation

struct JellyfinSession: Codable {
    var baseURL: String
    var accessToken: String
    var userId: String
    var userName: String
    var serverId: String?
    var deviceId: String
}

struct JellyfinAudioItem: Identifiable, Hashable {
    let id: String
    let name: String
    let artists: [String]
    let album: String?
    let albumId: String?
    let genres: [String]
    let imageTag: String?
    let albumPrimaryImageTag: String?
    let runtimeTicks: Int64?

    var durationSeconds: Double? {
        guard let runtimeTicks else { return nil }
        return Double(runtimeTicks) / 10_000_000.0
    }
}

struct JellyfinAudioPage: Hashable {
    let items: [JellyfinAudioItem]
    let startIndex: Int
    let totalRecordCount: Int?

    var hasMore: Bool {
        guard let totalRecordCount else {
            return !items.isEmpty
        }

        return startIndex + items.count < totalRecordCount
    }
}

struct JellyfinTrackPage: Hashable {
    let tracks: [Track]
    let nextStartIndex: Int
    let hasMore: Bool
    let totalRecordCount: Int?
}

enum JellyfinError: LocalizedError {
    case invalidServerURL
    case invalidResponse
    case httpError(Int, String?)
    case authenticationFailed
    case missingToken
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            return "Invalid Jellyfin server URL"

        case .invalidResponse:
            return "Invalid server response"

        case .httpError(let statusCode, let message):
            if let message, !message.isEmpty {
                return "Jellyfin API error (\(statusCode)): \(message)"
            }
            return "Jellyfin API error (\(statusCode))"

        case .authenticationFailed:
            return "Authentication failed"

        case .missingToken:
            return "Missing access token"

        case .notAuthenticated:
            return "Not authenticated with Jellyfin"
        }
    }
}
