//
//  NetworkActor.swift
//  NavidromeClient
//
//  Created by Boris Eder on 05.05.26.
//


//
//  NetworkActor.swift
//  NavidromeClient
//
//  NEW: Swift 6 Concurrency Refactoring — Step 2
//  Owns ALL URLSession calls, URL building, and auth token generation.
//  No UI state. No MainActor. Sendable.
//

import Foundation
import UIKit
import CryptoKit

actor NetworkActor {

    // MARK: - Configuration

    private let baseURL: URL
    private let username: String
    private let password: String

    // MARK: - URLSession per timeout profile

    private let defaultSession: URLSession    // 10s request / 30s resource
    private let contentSession: URLSession    // 15s request / 60s resource
    private let mediaSession: URLSession      // 20s request / 120s resource

    // MARK: - Init

    init(baseURL: URL, username: String, password: String) {
        self.baseURL = baseURL
        self.username = username
        self.password = password

        func makeSession(requestTimeout: TimeInterval, resourceTimeout: TimeInterval) -> URLSession {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = requestTimeout
            config.timeoutIntervalForResource = resourceTimeout
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            config.httpAdditionalHeaders = [
                "User-Agent": "NavidromeClient/1.0 iOS",
                "Accept": "application/json"
            ]
            config.urlCache = nil
            config.httpCookieAcceptPolicy = .never
            return URLSession(configuration: config)
        }

        defaultSession = makeSession(requestTimeout: 10, resourceTimeout: 30)
        contentSession = makeSession(requestTimeout: 15, resourceTimeout: 60)
        mediaSession   = makeSession(requestTimeout: 20, resourceTimeout: 120)
    }

    // MARK: - Generic JSON fetch

    func fetchData<T: Decodable & Sendable>(
        endpoint: String,
        params: [String: String] = [:],
        using session: URLSession? = nil
    ) async throws -> T {
        guard let url = buildURL(endpoint: endpoint, params: params) else {
            throw SubsonicError.badURL
        }

        let activeSession = session ?? defaultSession

        do {
            let (data, response) = try await activeSession.data(from: url)

            guard let http = response as? HTTPURLResponse else {
                throw SubsonicError.unknown
            }

            switch http.statusCode {
            case 200:
                do {
                    return try JSONDecoder().decode(T.self, from: data)
                } catch {
                    throw handleDecodingError(error, endpoint: endpoint)
                }
            case 401: throw SubsonicError.unauthorized
            case 429: throw SubsonicError.rateLimited
            default:  throw SubsonicError.server(statusCode: http.statusCode)
            }
        } catch {
            if error is SubsonicError { throw error }
            if let urlError = error as? URLError, urlError.code == .timedOut {
                throw SubsonicError.timeout(endpoint: endpoint)
            }
            throw SubsonicError.network(underlying: error)
        }
    }

    /// Fetch with a fallback value on empty-response errors
    func fetchDataWithFallback<T: Decodable & Sendable>(
        endpoint: String,
        params: [String: String] = [:],
        fallback: T
    ) async throws -> T {
        do {
            return try await fetchData(endpoint: endpoint, params: params)
        } catch {
            if let e = error as? SubsonicError, e.isEmptyResponse { return fallback }
            if case DecodingError.keyNotFound(let key, _) = error {
                let emptyKeys = ["albumList2", "artists", "genres", "album"]
                if emptyKeys.contains(key.stringValue) { return fallback }
            }
            throw error
        }
    }

    // MARK: - Raw data fetch (images)

    func fetchRawData(endpoint: String, params: [String: String] = [:]) async throws -> Data {
        guard let url = buildURL(endpoint: endpoint, params: params) else {
            throw SubsonicError.badURL
        }

        do {
            let (data, response) = try await mediaSession.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw SubsonicError.unknown
            }
            return data
        } catch {
            if error is SubsonicError { throw error }
            throw SubsonicError.network(underlying: error)
        }
    }

    // MARK: - Ping

    func ping() async throws -> PingInfo {
        let response: SubsonicResponse<PingInfo> = try await fetchData(endpoint: "ping")
        return response.subsonicResponse
    }

    // MARK: - Stream URL (pure computation, no network)

    nonisolated func streamURL(for songId: String) -> URL? {
        guard !songId.isEmpty else { return nil }
        return buildURL(endpoint: "stream", params: ["id": songId])
    }

    // MARK: - Auth header (for external use)

    nonisolated func authHeader() -> [String: String] {
        let loginString = "\(username):\(password)"
        guard let data = loginString.data(using: .utf8) else { return [:] }
        return ["Authorization": "Basic \(data.base64EncodedString())"]
    }

    // MARK: - URL Building

    nonisolated func buildURL(endpoint: String, params: [String: String] = [:]) -> URL? {
        guard validateEndpoint(endpoint) else { return nil }
        guard var components = URLComponents(string: baseURL.absoluteString) else { return nil }

        components.path = "/rest/\(endpoint).view"

        let salt  = generateSecureSalt()
        let token = (password + salt).md5()

        var queryItems = [
            URLQueryItem(name: "u", value: username),
            URLQueryItem(name: "t", value: token),
            URLQueryItem(name: "s", value: salt),
            URLQueryItem(name: "v", value: "1.16.1"),
            URLQueryItem(name: "c", value: "NavidromeClient")
        ]

        if endpoint != "stream" && endpoint != "download" {
            queryItems.append(URLQueryItem(name: "f", value: "json"))
        }

        for (key, value) in params {
            guard validateParameter(key: key, value: value) else { continue }
            queryItems.append(URLQueryItem(name: key, value: value))
        }

        components.queryItems = queryItems
        return components.url
    }

    // MARK: - Private helpers

    private nonisolated func validateEndpoint(_ endpoint: String) -> Bool {
        let allowed = [
            "ping", "getArtists", "getArtist", "getAlbum", "getAlbumList2",
            "getCoverArt", "stream", "download", "getGenres", "search2",
            "star", "unstar", "getStarred2"
        ]
        return allowed.contains(endpoint)
    }

    private nonisolated func validateParameter(key: String, value: String) -> Bool {
        guard key.count <= 50, value.count <= 1000 else { return false }
        let dangerous = CharacterSet(charactersIn: "<>\"'")
        return key.rangeOfCharacter(from: dangerous) == nil &&
               value.rangeOfCharacter(from: dangerous) == nil
    }

    private nonisolated func generateSecureSalt() -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<12).compactMap { _ in chars.randomElement() })
    }

    private nonisolated func handleDecodingError(_ error: Error, endpoint: String) -> SubsonicError {
        if case DecodingError.keyNotFound(let key, _) = error {
            let emptyKeys = ["album", "artist", "song", "genre"]
            if emptyKeys.contains(key.stringValue) {
                return SubsonicError.emptyResponse(endpoint: endpoint)
            }
        }
        return SubsonicError.decoding(underlying: error)
    }

    // Expose sessions for callers that need a specific timeout profile
    var contentURLSession: URLSession { contentSession }
    var mediaURLSession: URLSession { mediaSession }
}
