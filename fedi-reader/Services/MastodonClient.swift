//
//  MastodonClient.swift
//  fedi-reader
//
//  Core Mastodon API client with async/await
//

import Foundation

@Observable
@MainActor
final class MastodonClient {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    // Rate limiting state
    private var rateLimitRemaining: Int = Constants.API.defaultRateLimit
    private var rateLimitReset: Date?
    
    // Current authentication state (set by AuthService)
    var currentInstance: String?
    var currentAccessToken: String?
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Constants.API.defaultTimeout
        config.httpAdditionalHeaders = [
            "User-Agent": Constants.userAgent
        ]
        self.session = URLSession(configuration: config)
        
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try ISO8601 with fractional seconds
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(dateString)")
        }
        
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }
    
    // MARK: - Request Building
    
    private func buildURL(instance: String, path: String, queryItems: [URLQueryItem]? = nil) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = instance
        components.path = path
        components.queryItems = queryItems?.isEmpty == false ? queryItems : nil
        
        guard let url = components.url else {
            throw FediReaderError.invalidURL
        }
        return url
    }
    
    private func buildRequest(
        url: URL,
        method: String = "GET",
        accessToken: String? = nil,
        body: Data? = nil,
        contentType: String = "application/json"
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body {
            request.httpBody = body
        }
        
        return request
    }
    
    // MARK: - Request Execution
    
    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FediReaderError.invalidResponse
        }
        
        // Update rate limit info
        updateRateLimits(from: httpResponse)
        
        switch httpResponse.statusCode {
        case 200..<300:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw FediReaderError.decodingError(error)
            }
            
        case 401:
            throw FediReaderError.unauthorized
            
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { Double($0) }
            throw FediReaderError.rateLimited(retryAfter: retryAfter)
            
        default:
            let message = String(data: data, encoding: .utf8)
            throw FediReaderError.serverError(statusCode: httpResponse.statusCode, message: message)
        }
    }
    
    private func executeNoContent(_ request: URLRequest) async throws {
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FediReaderError.invalidResponse
        }
        
        updateRateLimits(from: httpResponse)
        
        switch httpResponse.statusCode {
        case 200..<300:
            return
        case 401:
            throw FediReaderError.unauthorized
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { Double($0) }
            throw FediReaderError.rateLimited(retryAfter: retryAfter)
        default:
            let message = String(data: data, encoding: .utf8)
            throw FediReaderError.serverError(statusCode: httpResponse.statusCode, message: message)
        }
    }
    
    private func updateRateLimits(from response: HTTPURLResponse) {
        if let remaining = response.value(forHTTPHeaderField: "X-RateLimit-Remaining"),
           let remainingInt = Int(remaining) {
            rateLimitRemaining = remainingInt
        }
        
        if let reset = response.value(forHTTPHeaderField: "X-RateLimit-Reset"),
           let resetTime = ISO8601DateFormatter().date(from: reset) {
            rateLimitReset = resetTime
        }
    }
    
    // MARK: - OAuth / App Registration
    
    func registerApp(instance: String) async throws -> OAuthApplication {
        let url = try buildURL(instance: instance, path: Constants.API.apps)
        
        let params: [String: String] = [
            "client_name": Constants.appName,
            "redirect_uris": Constants.OAuth.redirectURI,
            "scopes": Constants.OAuth.scopes,
            "website": Constants.OAuth.appWebsite
        ]
        
        let body = try encoder.encode(params)
        let request = buildRequest(url: url, method: "POST", body: body)
        
        return try await execute(request)
    }
    
    func buildAuthorizationURL(instance: String, clientId: String) throws -> URL {
        let queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "scope", value: Constants.OAuth.scopes),
            URLQueryItem(name: "redirect_uri", value: Constants.OAuth.redirectURI),
            URLQueryItem(name: "response_type", value: "code")
        ]
        
        return try buildURL(instance: instance, path: Constants.API.oauthAuthorize, queryItems: queryItems)
    }
    
    func exchangeCodeForToken(
        instance: String,
        clientId: String,
        clientSecret: String,
        code: String
    ) async throws -> OAuthToken {
        let url = try buildURL(instance: instance, path: Constants.API.oauthToken)
        
        let params: [String: String] = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "redirect_uri": Constants.OAuth.redirectURI,
            "grant_type": "authorization_code",
            "code": code,
            "scope": Constants.OAuth.scopes
        ]
        
        let body = try encoder.encode(params)
        let request = buildRequest(url: url, method: "POST", body: body)
        
        return try await execute(request)
    }
    
    func revokeToken(instance: String, clientId: String, clientSecret: String, token: String) async throws {
        let url = try buildURL(instance: instance, path: Constants.API.oauthRevoke)
        
        let params: [String: String] = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "token": token
        ]
        
        let body = try encoder.encode(params)
        let request = buildRequest(url: url, method: "POST", body: body)
        
        try await executeNoContent(request)
    }
    
    // MARK: - Account
    
    func verifyCredentials(instance: String, accessToken: String) async throws -> MastodonAccount {
        let url = try buildURL(instance: instance, path: Constants.API.verifyCredentials)
        let request = buildRequest(url: url, accessToken: accessToken)
        return try await execute(request)
    }
    
    func getAccount(instance: String, accessToken: String, id: String) async throws -> MastodonAccount {
        let url = try buildURL(instance: instance, path: "\(Constants.API.accounts)/\(id)")
        let request = buildRequest(url: url, accessToken: accessToken)
        return try await execute(request)
    }
    
    func getAccountStatuses(
        instance: String,
        accessToken: String,
        accountId: String,
        maxId: String? = nil,
        sinceId: String? = nil,
        limit: Int = Constants.Pagination.defaultLimit,
        excludeReplies: Bool = false,
        excludeReblogs: Bool = false,
        onlyMedia: Bool = false
    ) async throws -> [Status] {
        var queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "exclude_replies", value: String(excludeReplies)),
            URLQueryItem(name: "exclude_reblogs", value: String(excludeReblogs)),
            URLQueryItem(name: "only_media", value: String(onlyMedia))
        ]
        if let maxId { queryItems.append(URLQueryItem(name: "max_id", value: maxId)) }
        if let sinceId { queryItems.append(URLQueryItem(name: "since_id", value: sinceId)) }
        
        let url = try buildURL(instance: instance, path: "\(Constants.API.accounts)/\(accountId)/statuses", queryItems: queryItems)
        let request = buildRequest(url: url, accessToken: accessToken)
        return try await execute(request)
    }
    
    func getRelationships(instance: String, accessToken: String, ids: [String]) async throws -> [Relationship] {
        let queryItems = ids.map { URLQueryItem(name: "id[]", value: $0) }
        let url = try buildURL(instance: instance, path: "\(Constants.API.accounts)/relationships", queryItems: queryItems)
        let request = buildRequest(url: url, accessToken: accessToken)
        return try await execute(request)
    }
    
    func getAccountFollowers(
        instance: String,
        accessToken: String,
        accountId: String,
        maxId: String? = nil,
        limit: Int = Constants.Pagination.defaultLimit
    ) async throws -> [MastodonAccount] {
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let maxId { queryItems.append(URLQueryItem(name: "max_id", value: maxId)) }
        
        let url = try buildURL(instance: instance, path: "\(Constants.API.accounts)/\(accountId)/followers", queryItems: queryItems)
        let request = buildRequest(url: url, accessToken: accessToken)
        return try await execute(request)
    }
    
    func getAccountFollowing(
        instance: String,
        accessToken: String,
        accountId: String,
        maxId: String? = nil,
        limit: Int = Constants.Pagination.defaultLimit
    ) async throws -> [MastodonAccount] {
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let maxId { queryItems.append(URLQueryItem(name: "max_id", value: maxId)) }
        
        let url = try buildURL(instance: instance, path: "\(Constants.API.accounts)/\(accountId)/following", queryItems: queryItems)
        let request = buildRequest(url: url, accessToken: accessToken)
        return try await execute(request)
    }
    
    // MARK: - Timelines
    
    func getHomeTimeline(
        instance: String,
        accessToken: String,
        maxId: String? = nil,
        sinceId: String? = nil,
        minId: String? = nil,
        limit: Int = Constants.Pagination.defaultLimit
    ) async throws -> [Status] {
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let maxId { queryItems.append(URLQueryItem(name: "max_id", value: maxId)) }
        if let sinceId { queryItems.append(URLQueryItem(name: "since_id", value: sinceId)) }
        if let minId { queryItems.append(URLQueryItem(name: "min_id", value: minId)) }
        
        let url = try buildURL(instance: instance, path: Constants.API.homeTimeline, queryItems: queryItems)
        let request = buildRequest(url: url, accessToken: accessToken)
        return try await execute(request)
    }
    
    func getPublicTimeline(
        instance: String,
        accessToken: String? = nil,
        local: Bool = false,
        remote: Bool = false,
        onlyMedia: Bool = false,
        maxId: String? = nil,
        sinceId: String? = nil,
        limit: Int = Constants.Pagination.defaultLimit
    ) async throws -> [Status] {
        var queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "local", value: String(local)),
            URLQueryItem(name: "remote", value: String(remote)),
            URLQueryItem(name: "only_media", value: String(onlyMedia))
        ]
        if let maxId { queryItems.append(URLQueryItem(name: "max_id", value: maxId)) }
        if let sinceId { queryItems.append(URLQueryItem(name: "since_id", value: sinceId)) }
        
        let url = try buildURL(instance: instance, path: Constants.API.publicTimeline, queryItems: queryItems)
        let request = buildRequest(url: url, accessToken: accessToken)
        return try await execute(request)
    }
    
    // MARK: - Trending
    
    func getTrendingStatuses(
        instance: String,
        accessToken: String? = nil,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> [Status] {
        let queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]
        
        let url = try buildURL(instance: instance, path: Constants.API.trendingStatuses, queryItems: queryItems)
        let request = buildRequest(url: url, accessToken: accessToken)
        return try await execute(request)
    }
    
    func getTrendingLinks(
        instance: String,
        accessToken: String? = nil,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> [TrendingLink] {
        let queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]
        
        let url = try buildURL(instance: instance, path: Constants.API.trendingLinks, queryItems: queryItems)
        let request = buildRequest(url: url, accessToken: accessToken)
        return try await execute(request)
    }
    
    func getTrendingTags(
        instance: String,
        accessToken: String? = nil,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> [TrendingTag] {
        let queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]
        
        let url = try buildURL(instance: instance, path: Constants.API.trendingTags, queryItems: queryItems)
        let request = buildRequest(url: url, accessToken: accessToken)
        return try await execute(request)
    }
    
    // MARK: - Notifications
    
    func getNotifications(
        instance: String,
        accessToken: String,
        types: [NotificationType]? = nil,
        excludeTypes: [NotificationType]? = nil,
        maxId: String? = nil,
        sinceId: String? = nil,
        limit: Int = Constants.Pagination.defaultLimit
    ) async throws -> [MastodonNotification] {
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        
        if let types {
            for type in types {
                queryItems.append(URLQueryItem(name: "types[]", value: type.rawValue))
            }
        }
        
        if let excludeTypes {
            for type in excludeTypes {
                queryItems.append(URLQueryItem(name: "exclude_types[]", value: type.rawValue))
            }
        }
        
        if let maxId { queryItems.append(URLQueryItem(name: "max_id", value: maxId)) }
        if let sinceId { queryItems.append(URLQueryItem(name: "since_id", value: sinceId)) }
        
        let url = try buildURL(instance: instance, path: Constants.API.notifications, queryItems: queryItems)
        let request = buildRequest(url: url, accessToken: accessToken)
        return try await execute(request)
    }
    
    func getMentions(
        instance: String,
        accessToken: String,
        maxId: String? = nil,
        sinceId: String? = nil,
        limit: Int = Constants.Pagination.defaultLimit
    ) async throws -> [MastodonNotification] {
        try await getNotifications(
            instance: instance,
            accessToken: accessToken,
            types: [.mention],
            maxId: maxId,
            sinceId: sinceId,
            limit: limit
        )
    }

    func getConversations(
        instance: String,
        accessToken: String,
        maxId: String? = nil,
        sinceId: String? = nil,
        limit: Int = Constants.Pagination.defaultLimit
    ) async throws -> [MastodonConversation] {
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let maxId { queryItems.append(URLQueryItem(name: "max_id", value: maxId)) }
        if let sinceId { queryItems.append(URLQueryItem(name: "since_id", value: sinceId)) }

        let url = try buildURL(instance: instance, path: Constants.API.conversations, queryItems: queryItems)
        let request = buildRequest(url: url, accessToken: accessToken)
        return try await execute(request)
    }
    
    // MARK: - Statuses
    
    func getStatus(instance: String, accessToken: String, id: String) async throws -> Status {
        let url = try buildURL(instance: instance, path: "\(Constants.API.statuses)/\(id)")
        let request = buildRequest(url: url, accessToken: accessToken)
        return try await execute(request)
    }
    
    func getStatusContext(instance: String, accessToken: String, id: String) async throws -> StatusContext {
        let url = try buildURL(instance: instance, path: "\(Constants.API.statuses)/\(id)/context")
        let request = buildRequest(url: url, accessToken: accessToken)
        return try await execute(request)
    }
    
    func getStatusContext(id: String) async throws -> StatusContext {
        guard let instance = currentInstance, let token = currentAccessToken else {
            throw FediReaderError.noActiveAccount
        }
        return try await getStatusContext(instance: instance, accessToken: token, id: id)
    }
    
    func getStatus(id: String) async throws -> Status {
        guard let instance = currentInstance, let token = currentAccessToken else {
            throw FediReaderError.noActiveAccount
        }
        return try await getStatus(instance: instance, accessToken: token, id: id)
    }
    
    func getHashtagTimeline(tag: String, limit: Int = Constants.Pagination.defaultLimit) async throws -> [Status] {
        guard let instance = currentInstance, let token = currentAccessToken else {
            throw FediReaderError.noActiveAccount
        }
        return try await getHashtagTimeline(instance: instance, accessToken: token, tag: tag, limit: limit)
    }
    
    func searchAccounts(query: String, limit: Int = 10) async throws -> [MastodonAccount] {
        guard let instance = currentInstance, let token = currentAccessToken else {
            throw FediReaderError.noActiveAccount
        }
        let results = try await search(instance: instance, accessToken: token, query: query, type: "accounts", limit: limit)
        return results.accounts
    }
    
    func getHashtagTimeline(instance: String, accessToken: String, tag: String, limit: Int = Constants.Pagination.defaultLimit) async throws -> [Status] {
        let url = try buildURL(
            instance: instance,
            path: "/api/v1/timelines/tag/\(tag)",
            queryItems: [URLQueryItem(name: "limit", value: String(limit))]
        )
        let request = buildRequest(url: url, accessToken: accessToken)
        return try await execute(request)
    }
    
    func postStatus(
        instance: String,
        accessToken: String,
        status: String,
        inReplyToId: String? = nil,
        mediaIds: [String]? = nil,
        sensitive: Bool = false,
        spoilerText: String? = nil,
        visibility: Visibility = .public,
        language: String? = nil,
        quoteId: String? = nil
    ) async throws -> Status {
        let url = try buildURL(instance: instance, path: Constants.API.statuses)
        
        var params: [String: Any] = [
            "status": status,
            "sensitive": sensitive,
            "visibility": visibility.rawValue
        ]
        
        if let inReplyToId { params["in_reply_to_id"] = inReplyToId }
        if let mediaIds, !mediaIds.isEmpty { params["media_ids"] = mediaIds }
        if let spoilerText, !spoilerText.isEmpty { params["spoiler_text"] = spoilerText }
        if let language { params["language"] = language }
        if let quoteId { params["quote_id"] = quoteId } // For instances supporting quote posts
        
        let body = try JSONSerialization.data(withJSONObject: params)
        let request = buildRequest(url: url, method: "POST", accessToken: accessToken, body: body)
        
        return try await execute(request)
    }
    
    func deleteStatus(instance: String, accessToken: String, id: String) async throws -> Status {
        let url = try buildURL(instance: instance, path: "\(Constants.API.statuses)/\(id)")
        let request = buildRequest(url: url, method: "DELETE", accessToken: accessToken)
        return try await execute(request)
    }
    
    // MARK: - Status Actions
    
    func favorite(instance: String, accessToken: String, statusId: String) async throws -> Status {
        let url = try buildURL(instance: instance, path: "\(Constants.API.statuses)/\(statusId)/favourite")
        let request = buildRequest(url: url, method: "POST", accessToken: accessToken)
        return try await execute(request)
    }
    
    func unfavorite(instance: String, accessToken: String, statusId: String) async throws -> Status {
        let url = try buildURL(instance: instance, path: "\(Constants.API.statuses)/\(statusId)/unfavourite")
        let request = buildRequest(url: url, method: "POST", accessToken: accessToken)
        return try await execute(request)
    }
    
    func reblog(instance: String, accessToken: String, statusId: String, visibility: Visibility? = nil) async throws -> Status {
        let url = try buildURL(instance: instance, path: "\(Constants.API.statuses)/\(statusId)/reblog")
        
        var body: Data? = nil
        if let visibility {
            let params = ["visibility": visibility.rawValue]
            body = try encoder.encode(params)
        }
        
        let request = buildRequest(url: url, method: "POST", accessToken: accessToken, body: body)
        return try await execute(request)
    }
    
    func unreblog(instance: String, accessToken: String, statusId: String) async throws -> Status {
        let url = try buildURL(instance: instance, path: "\(Constants.API.statuses)/\(statusId)/unreblog")
        let request = buildRequest(url: url, method: "POST", accessToken: accessToken)
        return try await execute(request)
    }
    
    func bookmark(instance: String, accessToken: String, statusId: String) async throws -> Status {
        let url = try buildURL(instance: instance, path: "\(Constants.API.statuses)/\(statusId)/bookmark")
        let request = buildRequest(url: url, method: "POST", accessToken: accessToken)
        return try await execute(request)
    }
    
    func unbookmark(instance: String, accessToken: String, statusId: String) async throws -> Status {
        let url = try buildURL(instance: instance, path: "\(Constants.API.statuses)/\(statusId)/unbookmark")
        let request = buildRequest(url: url, method: "POST", accessToken: accessToken)
        return try await execute(request)
    }
    
    // MARK: - Search
    
    func search(
        instance: String,
        accessToken: String,
        query: String,
        type: String? = nil,
        resolve: Bool = true,
        limit: Int = 20
    ) async throws -> SearchResults {
        var queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "resolve", value: String(resolve)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let type { queryItems.append(URLQueryItem(name: "type", value: type)) }
        
        let url = try buildURL(instance: instance, path: Constants.API.search, queryItems: queryItems)
        let request = buildRequest(url: url, accessToken: accessToken)
        return try await execute(request)
    }
    
    // MARK: - Instance
    
    func getInstance(instance: String) async throws -> Instance {
        let url = try buildURL(instance: instance, path: Constants.API.instance)
        let request = buildRequest(url: url)
        return try await execute(request)
    }
    
    // MARK: - Lists
    
    func getLists(instance: String, accessToken: String) async throws -> [MastodonList] {
        let url = try buildURL(instance: instance, path: Constants.API.lists)
        let request = buildRequest(url: url, accessToken: accessToken)
        return try await execute(request)
    }
    
    func getLists() async throws -> [MastodonList] {
        guard let instance = currentInstance, let token = currentAccessToken else {
            throw FediReaderError.noActiveAccount
        }
        return try await getLists(instance: instance, accessToken: token)
    }
    
    func getListTimeline(
        instance: String,
        accessToken: String,
        listId: String,
        maxId: String? = nil,
        sinceId: String? = nil,
        minId: String? = nil,
        limit: Int = Constants.Pagination.defaultLimit
    ) async throws -> [Status] {
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let maxId { queryItems.append(URLQueryItem(name: "max_id", value: maxId)) }
        if let sinceId { queryItems.append(URLQueryItem(name: "since_id", value: sinceId)) }
        if let minId { queryItems.append(URLQueryItem(name: "min_id", value: minId)) }
        
        let url = try buildURL(instance: instance, path: "\(Constants.API.listTimeline)/\(listId)", queryItems: queryItems)
        let request = buildRequest(url: url, accessToken: accessToken)
        return try await execute(request)
    }
    
    func getListTimeline(
        listId: String,
        maxId: String? = nil,
        sinceId: String? = nil,
        limit: Int = Constants.Pagination.defaultLimit
    ) async throws -> [Status] {
        guard let instance = currentInstance, let token = currentAccessToken else {
            throw FediReaderError.noActiveAccount
        }
        return try await getListTimeline(
            instance: instance,
            accessToken: token,
            listId: listId,
            maxId: maxId,
            sinceId: sinceId,
            limit: limit
        )
    }
    
    func getListAccounts(
        instance: String,
        accessToken: String,
        listId: String,
        maxId: String? = nil,
        sinceId: String? = nil,
        limit: Int = Constants.Pagination.defaultLimit
    ) async throws -> [MastodonAccount] {
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let maxId { queryItems.append(URLQueryItem(name: "max_id", value: maxId)) }
        if let sinceId { queryItems.append(URLQueryItem(name: "since_id", value: sinceId)) }
        
        let url = try buildURL(instance: instance, path: "\(Constants.API.lists)/\(listId)/accounts", queryItems: queryItems)
        let request = buildRequest(url: url, accessToken: accessToken)
        return try await execute(request)
    }
    
    func getListAccounts(listId: String, limit: Int = Constants.Pagination.defaultLimit) async throws -> [MastodonAccount] {
        guard let instance = currentInstance, let token = currentAccessToken else {
            throw FediReaderError.noActiveAccount
        }
        return try await getListAccounts(instance: instance, accessToken: token, listId: listId, limit: limit)
    }
}
