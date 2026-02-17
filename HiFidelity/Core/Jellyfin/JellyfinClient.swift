import Foundation

actor JellyfinClient {
    private let session: URLSession
    private let appVersion: String

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true

        self.session = URLSession(configuration: config)
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    func authenticate(
        baseURL: String,
        username: String,
        password: String,
        deviceId: String
    ) async throws -> JellyfinSession {
        guard let url = URL(string: normalizedBaseURL(baseURL) + "/Users/AuthenticateByName") else {
            throw JellyfinError.invalidServerURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authorizationHeader(token: nil, deviceId: deviceId), forHTTPHeaderField: "Authorization")

        let payload = AuthenticateRequest(username: username, password: password)
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        let httpResponse = try validate(response: response, data: data)

        guard httpResponse.statusCode == 200 else {
            throw JellyfinError.authenticationFailed
        }

        let authResult = try JSONDecoder().decode(AuthenticationResultDTO.self, from: data)

        guard let token = authResult.accessToken, !token.isEmpty else {
            throw JellyfinError.missingToken
        }

        guard let userId = authResult.user?.id, !userId.isEmpty else {
            throw JellyfinError.authenticationFailed
        }

        return JellyfinSession(
            baseURL: normalizedBaseURL(baseURL),
            accessToken: token,
            userId: userId,
            userName: authResult.user?.name ?? username,
            serverId: authResult.serverId,
            deviceId: deviceId
        )
    }

    func fetchAudioItems(
        session jellyfinSession: JellyfinSession,
        startIndex: Int = 0,
        limit: Int = 50
    ) async throws -> [JellyfinAudioItem] {
        let page = try await fetchAudioItemsPage(
            session: jellyfinSession,
            startIndex: startIndex,
            limit: limit
        )
        return page.items
    }

    func fetchAudioItemsPage(
        session jellyfinSession: JellyfinSession,
        startIndex: Int = 0,
        limit: Int = 50
    ) async throws -> JellyfinAudioPage {
        var components = URLComponents(string: jellyfinSession.baseURL + "/Items")
        components?.queryItems = [
            URLQueryItem(name: "userId", value: jellyfinSession.userId),
            URLQueryItem(name: "includeItemTypes", value: "Audio"),
            URLQueryItem(name: "recursive", value: "true"),
            URLQueryItem(name: "sortBy", value: "SortName"),
            URLQueryItem(name: "sortOrder", value: "Ascending"),
            URLQueryItem(name: "startIndex", value: String(startIndex)),
            URLQueryItem(name: "limit", value: String(limit)),
        ]

        guard let url = components?.url else {
            throw JellyfinError.invalidServerURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(
            authorizationHeader(token: jellyfinSession.accessToken, deviceId: jellyfinSession.deviceId),
            forHTTPHeaderField: "Authorization"
        )

        let (data, response) = try await session.data(for: request)
        _ = try validate(response: response, data: data)

        let dto = try JSONDecoder().decode(ItemQueryResultDTO.self, from: data)
        let mapped = dto.items.map {
            JellyfinAudioItem(
                id: $0.id,
                name: $0.name ?? "Unknown",
                artists: $0.artists ?? [],
                album: $0.album,
                albumId: $0.albumId,
                genres: $0.genres ?? [],
                imageTag: $0.imageTags?.primary,
                albumPrimaryImageTag: $0.albumPrimaryImageTag,
                runtimeTicks: $0.runTimeTicks
            )
        }

        return JellyfinAudioPage(
            items: mapped,
            startIndex: startIndex,
            totalRecordCount: dto.totalRecordCount
        )
    }

    func buildAudioStreamURL(itemId: String, session jellyfinSession: JellyfinSession) -> URL? {
        var components = URLComponents(string: jellyfinSession.baseURL + "/Audio/\(itemId)/stream")
        components?.queryItems = [
            URLQueryItem(name: "static", value: "true"),
            URLQueryItem(name: "api_key", value: jellyfinSession.accessToken),
            URLQueryItem(name: "deviceId", value: jellyfinSession.deviceId),
            URLQueryItem(name: "userId", value: jellyfinSession.userId),
        ]

        return components?.url
    }

    func buildAudioTranscodeStreamURL(
        itemId: String,
        session jellyfinSession: JellyfinSession,
        maxStreamingBitrate: Int = 320_000,
        audioCodec: String = "aac",
        container: String = "mp4"
    ) -> URL? {
        var components = URLComponents(string: jellyfinSession.baseURL + "/Audio/\(itemId)/stream")
        components?.queryItems = [
            URLQueryItem(name: "static", value: "false"),
            URLQueryItem(name: "audioCodec", value: audioCodec),
            URLQueryItem(name: "container", value: container),
            URLQueryItem(name: "maxStreamingBitrate", value: String(maxStreamingBitrate)),
            URLQueryItem(name: "api_key", value: jellyfinSession.accessToken),
            URLQueryItem(name: "deviceId", value: jellyfinSession.deviceId),
            URLQueryItem(name: "userId", value: jellyfinSession.userId),
        ]

        return components?.url
    }

    func buildPrimaryImageURL(
        itemId: String,
        imageTag: String?,
        maxWidth: Int = 512,
        session jellyfinSession: JellyfinSession
    ) -> URL? {
        var components = URLComponents(string: jellyfinSession.baseURL + "/Items/\(itemId)/Images/Primary")

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "quality", value: "90"),
            URLQueryItem(name: "maxWidth", value: String(maxWidth)),
            URLQueryItem(name: "api_key", value: jellyfinSession.accessToken),
        ]

        if let imageTag, !imageTag.isEmpty {
            queryItems.append(URLQueryItem(name: "tag", value: imageTag))
        }

        components?.queryItems = queryItems
        return components?.url
    }

    private func normalizedBaseURL(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
    }

    private func authorizationHeader(token: String?, deviceId: String) -> String {
        var pairs: [String] = [
            "Client=\"HiFidelity\"",
            "Device=\"macOS\"",
            "DeviceId=\"\(deviceId)\"",
            "Version=\"\(appVersion)\"",
        ]

        if let token, !token.isEmpty {
            pairs.append("Token=\"\(token)\"")
        }

        return "MediaBrowser " + pairs.joined(separator: ", ")
    }

    @discardableResult
    private func validate(response: URLResponse, data: Data) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw JellyfinError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw JellyfinError.httpError(httpResponse.statusCode, message)
        }

        return httpResponse
    }
}

private struct AuthenticateRequest: Encodable {
    let Username: String
    let Pw: String

    init(username: String, password: String) {
        self.Username = username
        self.Pw = password
    }
}

private struct AuthenticationResultDTO: Decodable {
    let user: UserDTO?
    let accessToken: String?
    let serverId: String?

    private enum CodingKeys: String, CodingKey {
        case user = "User"
        case userCamel = "user"
        case accessToken = "AccessToken"
        case accessTokenCamel = "accessToken"
        case serverId = "ServerId"
        case serverIdCamel = "serverId"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        user = try container.decodeIfPresent(UserDTO.self, forKey: .user)
            ?? container.decodeIfPresent(UserDTO.self, forKey: .userCamel)
        accessToken = try container.decodeIfPresent(String.self, forKey: .accessToken)
            ?? container.decodeIfPresent(String.self, forKey: .accessTokenCamel)
        serverId = try container.decodeIfPresent(String.self, forKey: .serverId)
            ?? container.decodeIfPresent(String.self, forKey: .serverIdCamel)
    }
}

private struct UserDTO: Decodable {
    let id: String
    let name: String?

    private enum CodingKeys: String, CodingKey {
        case id = "Id"
        case idCamel = "id"
        case name = "Name"
        case nameCamel = "name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .idCamel)
            ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .nameCamel)
    }
}

private struct ItemQueryResultDTO: Decodable {
    let items: [BaseItemDTO]
    let totalRecordCount: Int?

    private enum CodingKeys: String, CodingKey {
        case items = "Items"
        case itemsCamel = "items"
        case totalRecordCount = "TotalRecordCount"
        case totalRecordCountCamel = "totalRecordCount"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decodeIfPresent([BaseItemDTO].self, forKey: .items)
            ?? container.decodeIfPresent([BaseItemDTO].self, forKey: .itemsCamel)
            ?? []
        totalRecordCount = try container.decodeIfPresent(Int.self, forKey: .totalRecordCount)
            ?? container.decodeIfPresent(Int.self, forKey: .totalRecordCountCamel)
    }
}

private struct BaseItemDTO: Decodable {
    let id: String
    let name: String?
    let artists: [String]?
    let album: String?
    let albumId: String?
    let genres: [String]?
    let imageTags: ImageTagsDTO?
    let albumPrimaryImageTag: String?
    let runTimeTicks: Int64?

    private enum CodingKeys: String, CodingKey {
        case id = "Id"
        case idCamel = "id"
        case name = "Name"
        case nameCamel = "name"
        case artists = "Artists"
        case artistsCamel = "artists"
        case album = "Album"
        case albumCamel = "album"
        case albumId = "AlbumId"
        case albumIdCamel = "albumId"
        case genres = "Genres"
        case genresCamel = "genres"
        case imageTags = "ImageTags"
        case imageTagsCamel = "imageTags"
        case albumPrimaryImageTag = "AlbumPrimaryImageTag"
        case albumPrimaryImageTagCamel = "albumPrimaryImageTag"
        case runTimeTicks = "RunTimeTicks"
        case runTimeTicksCamel = "runTimeTicks"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .idCamel)
            ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .nameCamel)
        artists = try container.decodeIfPresent([String].self, forKey: .artists)
            ?? container.decodeIfPresent([String].self, forKey: .artistsCamel)
        album = try container.decodeIfPresent(String.self, forKey: .album)
            ?? container.decodeIfPresent(String.self, forKey: .albumCamel)
        albumId = try container.decodeIfPresent(String.self, forKey: .albumId)
            ?? container.decodeIfPresent(String.self, forKey: .albumIdCamel)
        genres = try container.decodeIfPresent([String].self, forKey: .genres)
            ?? container.decodeIfPresent([String].self, forKey: .genresCamel)
        imageTags = try container.decodeIfPresent(ImageTagsDTO.self, forKey: .imageTags)
            ?? container.decodeIfPresent(ImageTagsDTO.self, forKey: .imageTagsCamel)
        albumPrimaryImageTag = try container.decodeIfPresent(String.self, forKey: .albumPrimaryImageTag)
            ?? container.decodeIfPresent(String.self, forKey: .albumPrimaryImageTagCamel)
        runTimeTicks = try container.decodeIfPresent(Int64.self, forKey: .runTimeTicks)
            ?? container.decodeIfPresent(Int64.self, forKey: .runTimeTicksCamel)
    }
}

private struct ImageTagsDTO: Decodable {
    let primary: String?

    private enum CodingKeys: String, CodingKey {
        case primary = "Primary"
        case primaryCamel = "primary"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        primary = try container.decodeIfPresent(String.self, forKey: .primary)
            ?? container.decodeIfPresent(String.self, forKey: .primaryCamel)
    }
}
