//
//  MastodonClient.swift
//  fedi-reader
//
//  Core Mastodon API client with async/await
//

import Foundation
import os

@Observable
@MainActor
final class MastodonClient {
    private static let logger = Logger(subsystem: "app.fedi-reader", category: "MastodonClient")
    
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
        // Security: Validate instance format to prevent SSRF attacks
        // Instance should be a valid hostname without protocol
        guard !instance.isEmpty,
              !instance.contains("://"),
              !instance.contains("/"),
              !instance.contains("?"),
              !instance.contains("#"),
              instance.range(of: #"^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$"#, options: .regularExpression) != nil else {
            Self.logger.error("Invalid instance format: \(instance, privacy: .public)")
            throw FediReaderError.invalidURL
        }
        
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

    private func formEncodedBody(_ items: [URLQueryItem]) -> Data? {
        var components = URLComponents()
        components.queryItems = items
        return components.percentEncodedQuery?.data(using: .utf8)
    }
    
    // MARK: - Request Execution
    
    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (result, _): (T, HTTPURLResponse) = try await executeWithHeaders(request)
        return result
    }
    
    private func executeWithHeaders<T: Decodable>(_ request: URLRequest) async throws -> (T, HTTPURLResponse) {
        let startTime = Date()
        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? "unknown"
        
        Self.logger.info("API request: \(method) \(url, privacy: .public)")
        
        do {
            let (data, response) = try await session.data(for: request)
            let duration = Date().timeIntervalSince(startTime)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                Self.logger.error("Invalid response type for \(url, privacy: .public)")
                throw FediReaderError.invalidResponse
            }
            
            let statusCode = httpResponse.statusCode
            let dataSize = data.count
            
            // Update rate limit info
            updateRateLimits(from: httpResponse)
            
            switch statusCode {
            case 200..<300:
                do {
                    let result = try decoder.decode(T.self, from: data)
                    Self.logger.info("API success: \(method) \(url, privacy: .public) - \(statusCode) (\(dataSize) bytes) in \(String(format: "%.2f", duration))s")
                    return (result, httpResponse)
                } catch {
                    Self.logger.error("Decoding error for \(method) \(url, privacy: .public): \(error.localizedDescription)")
                    throw FediReaderError.decodingError(error)
                }
                
            case 401:
                Self.logger.error("Unauthorized: \(method) \(url, privacy: .public)")
                throw FediReaderError.unauthorized
                
            case 429:
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                    .flatMap { Double($0) }
                Self.logger.warning("Rate limited: \(method) \(url, privacy: .public), retry after: \(retryAfter?.description ?? "unknown")")
                throw FediReaderError.rateLimited(retryAfter: retryAfter)
                
            default:
                let message = String(data: data, encoding: .utf8)
                Self.logger.error("Server error: \(method) \(url, privacy: .public) - \(statusCode): \(message ?? "no message", privacy: .public)")
                throw FediReaderError.serverError(statusCode: statusCode, message: message)
            }
        } catch let error as FediReaderError {
            throw error
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            Self.logger.error("Network error: \(method) \(url, privacy: .public) after \(String(format: "%.2f", duration))s: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func executeNoContent(_ request: URLRequest) async throws {
        let startTime = Date()
        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? "unknown"
        
        Self.logger.info("API request (no content): \(method) \(url, privacy: .public)")
        
        do {
            let (data, response) = try await session.data(for: request)
            let duration = Date().timeIntervalSince(startTime)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                Self.logger.error("Invalid response type for \(url, privacy: .public)")
                throw FediReaderError.invalidResponse
            }
            
            let statusCode = httpResponse.statusCode
            
            updateRateLimits(from: httpResponse)
            
            switch statusCode {
            case 200..<300:
                Self.logger.info("API success: \(method) \(url, privacy: .public) - \(statusCode) in \(String(format: "%.2f", duration))s")
                return
            case 401:
                Self.logger.error("Unauthorized: \(method) \(url, privacy: .public)")
                throw FediReaderError.unauthorized
            case 429:
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                    .flatMap { Double($0) }
                Self.logger.warning("Rate limited: \(method) \(url, privacy: .public), retry after: \(retryAfter?.description ?? "unknown")")
                throw FediReaderError.rateLimited(retryAfter: retryAfter)
            default:
                let message = String(data: data, encoding: .utf8)
                Self.logger.error("Server error: \(method) \(url, privacy: .public) - \(statusCode): \(message ?? "no message", privacy: .public)")
                throw FediReaderError.serverError(statusCode: statusCode, message: message)
            }
        } catch let error as FediReaderError {
            throw error
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            Self.logger.error("Network error: \(method) \(url, privacy: .public) after \(String(format: "%.2f", duration))s: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func updateRateLimits(from response: HTTPURLResponse) {
        if let remaining = response.value(forHTTPHeaderField: "X-RateLimit-Remaining"),
           let remainingInt = Int(remaining) {
            let previousRemaining = rateLimitRemaining
            rateLimitRemaining = remainingInt
            if previousRemaining != remainingInt {
                Self.logger.debug("Rate limit updated: \(remainingInt) remaining")
            }
        }
        
        if let reset = response.value(forHTTPHeaderField: "X-RateLimit-Reset"),
           let resetTime = ISO8601DateFormatter().date(from: reset) {
            rateLimitReset = resetTime
            Self.logger.debug("Rate limit resets at: \(resetTime.formatted())")
        }
    }
    
    // MARK: - OAuth / App Registration
    
    func registerApp(instance: String) async throws -> OAuthApplication {
        Self.logger.info("Registering app on instance: \(instance, privacy: .public)")
        let url = try buildURL(instance: instance, path: Constants.API.apps)
        
        let params: [String: String] = [
            "client_name": Constants.appName,
            "redirect_uris": Constants.OAuth.redirectURI,
            "scopes": Constants.OAuth.scopes,
            "website": Constants.OAuth.appWebsite
        ]
        
        let body = try encoder.encode(params)
        let request = buildRequest(url: url, method: "POST", body: body)
        
        let result: OAuthApplication = try await execute(request)
        Self.logger.info("App registered successfully on \(instance, privacy: .public)")
        return result
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
        Self.logger.info("Exchanging OAuth code for token on instance: \(instance, privacy: .public)")
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
        
        let result: OAuthToken = try await execute(request)
        Self.logger.info("OAuth token exchange successful for \(instance, privacy: .public)")
        return result
    }
    
    func revokeToken(instance: String, clientId: String, clientSecret: String, token: String) async throws {
        Self.logger.info("Revoking OAuth token on instance: \(instance, privacy: .public)")
        let url = try buildURL(instance: instance, path: Constants.API.oauthRevoke)
        
        let params: [String: String] = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "token": token
        ]
        
        let body = try encoder.encode(params)
        let request = buildRequest(url: url, method: "POST", body: body)
        
        try await executeNoContent(request)
        Self.logger.info("OAuth token revoked successfully for \(instance, privacy: .public)")
    }
    
    // MARK: - Account
    
    func verifyCredentials(instance: String, accessToken: String) async throws -> MastodonAccount {
        Self.logger.info("Verifying credentials on instance: \(instance, privacy: .public)")
        let url = try buildURL(
            instance: instance,
            path: Constants.API.verifyCredentials,
            queryItems: [URLQueryItem(name: "with_source", value: "true")]
        )
        let request = buildRequest(url: url, accessToken: accessToken)
        let account: MastodonAccount = try await execute(request)
        Self.logger.info("Credentials verified for account: \(account.username, privacy: .public)@\(instance, privacy: .public)")
        return account
    }
    
    func getAccount(instance: String, accessToken: String, id: String) async throws -> MastodonAccount {
        Self.logger.debug("Fetching account \(id, privacy: .public) from instance: \(instance, privacy: .public)")
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
        Self.logger.debug("Fetching account statuses for \(accountId, privacy: .public), limit: \(limit), maxId: \(maxId?.prefix(8) ?? "nil", privacy: .public)")
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
        let statuses: [Status] = try await execute(request)
        Self.logger.debug("Fetched \(statuses.count) account statuses for \(accountId, privacy: .public)")
        return statuses
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

    func getAccountFeaturedTags(
        instance: String,
        accessToken: String,
        accountId: String
    ) async throws -> [Tag] {
        let url = try buildURL(instance: instance, path: "\(Constants.API.accounts)/\(accountId)/featured_tags")
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
        Self.logger.info("Fetching home timeline, limit: \(limit), maxId: \(maxId?.prefix(8) ?? "nil", privacy: .public), sinceId: \(sinceId?.prefix(8) ?? "nil", privacy: .public)")
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let maxId { queryItems.append(URLQueryItem(name: "max_id", value: maxId)) }
        if let sinceId { queryItems.append(URLQueryItem(name: "since_id", value: sinceId)) }
        if let minId { queryItems.append(URLQueryItem(name: "min_id", value: minId)) }
        
        let url = try buildURL(instance: instance, path: Constants.API.homeTimeline, queryItems: queryItems)
        let request = buildRequest(url: url, accessToken: accessToken)
        let statuses: [Status] = try await execute(request)
        Self.logger.info("Home timeline loaded: \(statuses.count) statuses")
        return statuses
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
        Self.logger.debug("Fetching trending statuses, limit: \(limit), offset: \(offset)")
        let queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]
        
        let url = try buildURL(instance: instance, path: Constants.API.trendingStatuses, queryItems: queryItems)
        let request = buildRequest(url: url, accessToken: accessToken)
        let statuses: [Status] = try await execute(request)
        Self.logger.debug("Fetched \(statuses.count) trending statuses")
        return statuses
    }
    
    func getTrendingLinks(
        instance: String,
        accessToken: String? = nil,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> [TrendingLink] {
        Self.logger.debug("Fetching trending links, limit: \(limit), offset: \(offset)")
        let queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]
        
        let url = try buildURL(instance: instance, path: Constants.API.trendingLinks, queryItems: queryItems)
        let request = buildRequest(url: url, accessToken: accessToken)
        let links: [TrendingLink] = try await execute(request)
        Self.logger.debug("Fetched \(links.count) trending links")
        return links
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
        Self.logger.info("Fetching mentions, limit: \(limit), maxId: \(maxId?.prefix(8) ?? "nil", privacy: .public)")
        let notifications = try await getNotifications(
            instance: instance,
            accessToken: accessToken,
            types: [.mention],
            maxId: maxId,
            sinceId: sinceId,
            limit: limit
        )
        Self.logger.info("Fetched \(notifications.count) mentions")
        return notifications
    }

    func getConversations(
        instance: String,
        accessToken: String,
        maxId: String? = nil,
        sinceId: String? = nil,
        limit: Int = Constants.Pagination.defaultLimit
    ) async throws -> [MastodonConversation] {
        Self.logger.info("Fetching conversations, limit: \(limit), maxId: \(maxId?.prefix(8) ?? "nil", privacy: .public)")
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let maxId { queryItems.append(URLQueryItem(name: "max_id", value: maxId)) }
        if let sinceId { queryItems.append(URLQueryItem(name: "since_id", value: sinceId)) }

        let url = try buildURL(instance: instance, path: Constants.API.conversations, queryItems: queryItems)
        let request = buildRequest(url: url, accessToken: accessToken)
        let conversations: [MastodonConversation] = try await execute(request)
        Self.logger.info("Fetched \(conversations.count) conversations")
        return conversations
    }
    
    func markConversationAsRead(
        instance: String,
        accessToken: String,
        conversationId: String
    ) async throws -> MastodonConversation {
        Self.logger.info("Marking conversation as read: \(conversationId.prefix(8), privacy: .public)")
        let url = try buildURL(instance: instance, path: "\(Constants.API.conversations)/\(conversationId)/read")
        let request = buildRequest(url: url, method: "POST", accessToken: accessToken)
        let conversation: MastodonConversation = try await execute(request)
        Self.logger.info("Conversation marked as read: \(conversationId.prefix(8), privacy: .public)")
        return conversation
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
    
    // MARK: - Status Context with Async Refresh Support
    
    struct StatusContextWithRefresh: Sendable {
        let context: StatusContext
        let asyncRefreshHeader: AsyncRefreshHeader?
    }
    
    func getStatusContextWithRefresh(instance: String, accessToken: String, id: String) async throws -> StatusContextWithRefresh {
        Self.logger.debug("Fetching status context with refresh support for status: \(id.prefix(8), privacy: .public)")
        let url = try buildURL(instance: instance, path: "\(Constants.API.statuses)/\(id)/context")
        let request = buildRequest(url: url, accessToken: accessToken)
        
        let result: (StatusContext, HTTPURLResponse) = try await executeWithHeaders(request)
        let (context, httpResponse) = result
        
        let rawHeader = httpResponse.value(forHTTPHeaderField: Constants.RemoteReplies.asyncRefreshHeader)
        let asyncRefreshHeader = AsyncRefreshHeader.parse(headerValue: rawHeader)
        if let h = asyncRefreshHeader {
            Self.logger.info("Async refresh detected for status context: id=\(h.id.prefix(12), privacy: .public), retry=\(h.retrySeconds)")
        }
        
        let enhancedContext = StatusContext(
            ancestors: context.ancestors,
            descendants: context.descendants,
            hasMoreReplies: context.hasMoreReplies,
            asyncRefreshId: asyncRefreshHeader?.id ?? context.asyncRefreshId
        )
        
        return StatusContextWithRefresh(context: enhancedContext, asyncRefreshHeader: asyncRefreshHeader)
    }
    
    func getStatusContextWithRefresh(id: String) async throws -> StatusContextWithRefresh {
        guard let instance = currentInstance, let token = currentAccessToken else {
            throw FediReaderError.noActiveAccount
        }
        return try await getStatusContextWithRefresh(instance: instance, accessToken: token, id: id)
    }
    
    // MARK: - Async Refreshes (Mastodon 4.5+)
    
    func getAsyncRefresh(instance: String, accessToken: String, id: String) async throws -> AsyncRefresh {
        let url = try buildURL(instance: instance, path: "\(Constants.API.asyncRefreshes)/\(id)")
        let request = buildRequest(url: url, accessToken: accessToken)
        let wrapper: AsyncRefreshResponse = try await execute(request)
        return wrapper.asyncRefresh
    }
    
    func getAsyncRefresh(id: String) async throws -> AsyncRefresh {
        guard let instance = currentInstance, let token = currentAccessToken else {
            throw FediReaderError.noActiveAccount
        }
        return try await getAsyncRefresh(instance: instance, accessToken: token, id: id)
    }
    
    // MARK: - Remote Status Resolution
    
    func resolveStatus(instance: String, accessToken: String, uri: String) async throws -> Status? {
        Self.logger.debug("Resolving remote status URI: \(uri, privacy: .public)")
        
        // Security: Validate URI format
        guard let uriURL = URL(string: uri),
              let scheme = uriURL.scheme,
              (scheme == "https" || scheme == "http"),
              uriURL.host != nil else {
            Self.logger.warning("Invalid URI format for status resolution: \(uri, privacy: .public)")
            return nil
        }
        
        // Try search API first (Mastodon v2 search with resolve=true)
        do {
            let results = try await search(
                instance: instance,
                accessToken: accessToken,
                query: uri,
                type: "statuses",
                resolve: true,
                limit: 1
            )
            
            if let status = results.statuses.first {
                Self.logger.info("Resolved remote status via search API: \(status.id.prefix(8), privacy: .public)")
                return status
            }
        } catch {
            Self.logger.debug("Search API resolution failed, will try ActivityPub: \(error.localizedDescription)")
        }
        
        // Fallback: Try ActivityPub resolution
        return try await resolveStatusViaActivityPub(uri: uri, instance: instance, accessToken: accessToken)
    }
    
    func resolveStatus(uri: String) async throws -> Status? {
        guard let instance = currentInstance, let token = currentAccessToken else {
            throw FediReaderError.noActiveAccount
        }
        return try await resolveStatus(instance: instance, accessToken: token, uri: uri)
    }
    
    private func resolveStatusViaActivityPub(uri: String, instance: String, accessToken: String) async throws -> Status? {
        guard let uriURL = URL(string: uri) else {
            return nil
        }
        
        // Security: Validate remote host to prevent SSRF
        guard let host = uriURL.host,
              host != instance else {
            // Only resolve remote instances, not local ones
            return nil
        }
        
        // Build request to remote instance's ActivityPub endpoint
        var components = URLComponents()
        components.scheme = uriURL.scheme ?? "https"
        components.host = host
        components.path = uriURL.path
        
        guard let activityPubURL = components.url else {
            return nil
        }
        
        var request = URLRequest(url: activityPubURL)
        request.setValue(Constants.ActivityPub.acceptHeader, forHTTPHeaderField: "Accept")
        request.setValue(Constants.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = Constants.RemoteReplies.fetchTimeout
        
        Self.logger.debug("Attempting ActivityPub resolution for: \(uri, privacy: .public)")
        
        do {
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                Self.logger.debug("ActivityPub resolution failed: invalid response type")
                return nil
            }
            
            // Handle different status codes gracefully
            switch httpResponse.statusCode {
            case 200..<300:
                // Try to parse as ActivityPub Note/Status
                // For now, we'll return nil as ActivityPub parsing is complex
                // In a full implementation, we'd parse the ActivityPub JSON-LD
                Self.logger.debug("ActivityPub response received but parsing not fully implemented")
                return nil
            case 404:
                Self.logger.debug("ActivityPub resolution: status not found (404)")
                return nil
            case 403, 401:
                Self.logger.debug("ActivityPub resolution: access denied (\(httpResponse.statusCode))")
                return nil
            default:
                Self.logger.debug("ActivityPub resolution failed: HTTP \(httpResponse.statusCode)")
                return nil
            }
        } catch let error as URLError {
            // Handle specific network errors
            switch error.code {
            case .timedOut:
                Self.logger.debug("ActivityPub resolution timed out for: \(uri.prefix(50), privacy: .public)")
            case .notConnectedToInternet, .networkConnectionLost:
                Self.logger.debug("ActivityPub resolution: no network connection")
            case .cannotFindHost, .cannotConnectToHost:
                Self.logger.debug("ActivityPub resolution: cannot connect to host")
            default:
                Self.logger.debug("ActivityPub resolution failed: \(error.localizedDescription)")
            }
            return nil
        } catch {
            Self.logger.debug("ActivityPub resolution failed: \(error.localizedDescription)")
            return nil
        }
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
        Self.logger.info("Posting status, visibility: \(visibility.rawValue, privacy: .public), replyTo: \(inReplyToId?.prefix(8) ?? "nil", privacy: .public), mediaCount: \(mediaIds?.count ?? 0)")
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
        
        let result: Status = try await execute(request)
        Self.logger.info("Status posted successfully: \(result.id, privacy: .public)")
        return result
    }
    
    func deleteStatus(instance: String, accessToken: String, id: String) async throws -> Status {
        let url = try buildURL(instance: instance, path: "\(Constants.API.statuses)/\(id)")
        let request = buildRequest(url: url, method: "DELETE", accessToken: accessToken)
        return try await execute(request)
    }
    
    // MARK: - Status Actions
    
    func favorite(instance: String, accessToken: String, statusId: String) async throws -> Status {
        Self.logger.info("Favoriting status: \(statusId.prefix(8), privacy: .public)")
        let url = try buildURL(instance: instance, path: "\(Constants.API.statuses)/\(statusId)/favourite")
        let request = buildRequest(url: url, method: "POST", accessToken: accessToken)
        return try await execute(request)
    }
    
    func unfavorite(instance: String, accessToken: String, statusId: String) async throws -> Status {
        Self.logger.info("Unfavoriting status: \(statusId.prefix(8), privacy: .public)")
        let url = try buildURL(instance: instance, path: "\(Constants.API.statuses)/\(statusId)/unfavourite")
        let request = buildRequest(url: url, method: "POST", accessToken: accessToken)
        return try await execute(request)
    }
    
    func reblog(instance: String, accessToken: String, statusId: String, visibility: Visibility? = nil) async throws -> Status {
        Self.logger.info("Reblogging status: \(statusId.prefix(8), privacy: .public), visibility: \(visibility?.rawValue ?? "default", privacy: .public)")
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
        Self.logger.info("Unreblogging status: \(statusId.prefix(8), privacy: .public)")
        let url = try buildURL(instance: instance, path: "\(Constants.API.statuses)/\(statusId)/unreblog")
        let request = buildRequest(url: url, method: "POST", accessToken: accessToken)
        return try await execute(request)
    }
    
    func bookmark(instance: String, accessToken: String, statusId: String) async throws -> Status {
        Self.logger.info("Bookmarking status: \(statusId.prefix(8), privacy: .public)")
        let url = try buildURL(instance: instance, path: "\(Constants.API.statuses)/\(statusId)/bookmark")
        let request = buildRequest(url: url, method: "POST", accessToken: accessToken)
        return try await execute(request)
    }
    
    func unbookmark(instance: String, accessToken: String, statusId: String) async throws -> Status {
        Self.logger.info("Unbookmarking status: \(statusId.prefix(8), privacy: .public)")
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
    
    func getCustomEmojis(instance: String) async throws -> [CustomEmoji] {
        Self.logger.debug("Fetching custom emoji from instance: \(instance, privacy: .public)")
        let url = try buildURL(instance: instance, path: Constants.API.customEmojis)
        let request = buildRequest(url: url)
        let emojis: [CustomEmoji] = try await execute(request)
        Self.logger.debug("Fetched \(emojis.count) custom emoji from \(instance, privacy: .public)")
        return emojis
    }
    
    func getCustomEmojis() async throws -> [CustomEmoji] {
        guard let instance = currentInstance else {
            throw FediReaderError.noActiveAccount
        }
        return try await getCustomEmojis(instance: instance)
    }
    
    // MARK: - Lists
    
    func getLists(instance: String, accessToken: String) async throws -> [MastodonList] {
        Self.logger.debug("Fetching lists")
        let url = try buildURL(instance: instance, path: Constants.API.lists)
        let request = buildRequest(url: url, accessToken: accessToken)
        let lists: [MastodonList] = try await execute(request)
        Self.logger.debug("Fetched \(lists.count) lists")
        return lists
    }
    
    func getLists() async throws -> [MastodonList] {
        guard let instance = currentInstance, let token = currentAccessToken else {
            throw FediReaderError.noActiveAccount
        }
        return try await getLists(instance: instance, accessToken: token)
    }

    func getAccountLists(instance: String, accessToken: String, accountId: String) async throws -> [MastodonList] {
        Self.logger.debug("Fetching lists for account \(accountId.prefix(8), privacy: .public)")
        let url = try buildURL(instance: instance, path: "\(Constants.API.accounts)/\(accountId)/lists")
        let request = buildRequest(url: url, accessToken: accessToken)
        let lists: [MastodonList] = try await execute(request)
        Self.logger.debug("Fetched \(lists.count) lists for account")
        return lists
    }

    func getAccountLists(accountId: String) async throws -> [MastodonList] {
        guard let instance = currentInstance, let token = currentAccessToken else {
            throw FediReaderError.noActiveAccount
        }
        return try await getAccountLists(instance: instance, accessToken: token, accountId: accountId)
    }

    func createList(instance: String, accessToken: String, title: String) async throws -> MastodonList {
        Self.logger.debug("Creating list with title \(title, privacy: .public)")
        let url = try buildURL(instance: instance, path: Constants.API.lists)
        let body = formEncodedBody([URLQueryItem(name: "title", value: title)])
        let request = buildRequest(
            url: url,
            method: "POST",
            accessToken: accessToken,
            body: body,
            contentType: "application/x-www-form-urlencoded"
        )
        let list: MastodonList = try await execute(request)
        Self.logger.debug("Created list \(list.id.prefix(8), privacy: .public)")
        return list
    }

    func createList(title: String) async throws -> MastodonList {
        guard let instance = currentInstance, let token = currentAccessToken else {
            throw FediReaderError.noActiveAccount
        }
        return try await createList(instance: instance, accessToken: token, title: title)
    }

    func addAccountsToList(instance: String, accessToken: String, listId: String, accountIds: [String]) async throws {
        Self.logger.debug("Adding \(accountIds.count, privacy: .public) accounts to list \(listId.prefix(8), privacy: .public)")
        let url = try buildURL(instance: instance, path: "\(Constants.API.lists)/\(listId)/accounts")
        let items = accountIds.map { URLQueryItem(name: "account_ids[]", value: $0) }
        let body = formEncodedBody(items)
        let request = buildRequest(
            url: url,
            method: "POST",
            accessToken: accessToken,
            body: body,
            contentType: "application/x-www-form-urlencoded"
        )
        try await executeNoContent(request)
    }

    func addAccountsToList(listId: String, accountIds: [String]) async throws {
        guard let instance = currentInstance, let token = currentAccessToken else {
            throw FediReaderError.noActiveAccount
        }
        try await addAccountsToList(instance: instance, accessToken: token, listId: listId, accountIds: accountIds)
    }

    func removeAccountsFromList(instance: String, accessToken: String, listId: String, accountIds: [String]) async throws {
        Self.logger.debug("Removing \(accountIds.count, privacy: .public) accounts from list \(listId.prefix(8), privacy: .public)")
        let url = try buildURL(instance: instance, path: "\(Constants.API.lists)/\(listId)/accounts")
        let items = accountIds.map { URLQueryItem(name: "account_ids[]", value: $0) }
        let body = formEncodedBody(items)
        let request = buildRequest(
            url: url,
            method: "DELETE",
            accessToken: accessToken,
            body: body,
            contentType: "application/x-www-form-urlencoded"
        )
        try await executeNoContent(request)
    }

    func removeAccountsFromList(listId: String, accountIds: [String]) async throws {
        guard let instance = currentInstance, let token = currentAccessToken else {
            throw FediReaderError.noActiveAccount
        }
        try await removeAccountsFromList(instance: instance, accessToken: token, listId: listId, accountIds: accountIds)
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
        Self.logger.info("Fetching list timeline \(listId.prefix(8), privacy: .public), limit: \(limit), maxId: \(maxId?.prefix(8) ?? "nil", privacy: .public)")
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let maxId { queryItems.append(URLQueryItem(name: "max_id", value: maxId)) }
        if let sinceId { queryItems.append(URLQueryItem(name: "since_id", value: sinceId)) }
        if let minId { queryItems.append(URLQueryItem(name: "min_id", value: minId)) }
        
        let url = try buildURL(instance: instance, path: "\(Constants.API.listTimeline)/\(listId)", queryItems: queryItems)
        let request = buildRequest(url: url, accessToken: accessToken)
        let statuses: [Status] = try await execute(request)
        Self.logger.info("List timeline loaded: \(statuses.count) statuses")
        return statuses
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
