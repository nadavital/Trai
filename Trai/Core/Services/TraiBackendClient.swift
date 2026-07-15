import Foundation

enum BackendClientError: LocalizedError {
    case environmentNotConfigured
    case invalidResponse
    case unauthorized
    case serverError(statusCode: Int, code: String?, message: String)
    case encodingFailure

    var errorDescription: String? {
        switch self {
        case .environmentNotConfigured:
            "Backend environment is not configured yet."
        case .invalidResponse:
            "The backend returned an invalid response."
        case .unauthorized:
            "Your session is no longer valid. Please sign in again."
        case .serverError(_, _, let message):
            message
        case .encodingFailure:
            "Failed to encode the backend request."
        }
    }
}

private struct BackendErrorPayload: Decodable {
    var error: String?
    var message: String?
}

final class TraiBackendClient {
    static let shared = TraiBackendClient()

    private enum RequestPolicy {
        static let timeoutInterval: TimeInterval = 30
        static let maximumReadAttempts = 2
        static let initialRetryDelay: Duration = .milliseconds(250)

        static func shouldRetry(statusCode: Int) -> Bool {
            statusCode == 408
                || statusCode == 425
                || statusCode == 429
                || [500, 502, 503, 504].contains(statusCode)
        }

        static func shouldRetry(error: Error) -> Bool {
            guard !Task.isCancelled, let urlError = error as? URLError else { return false }

            switch urlError.code {
            case .timedOut,
                 .cannotFindHost,
                 .cannotConnectToHost,
                 .networkConnectionLost,
                 .dnsLookupFailed,
                 .notConnectedToInternet,
                 .resourceUnavailable:
                return true
            case .cancelled:
                return false
            default:
                return false
            }
        }

        static func retryDelay(for response: HTTPURLResponse) -> Duration {
            guard [429, 503].contains(response.statusCode),
                  let rawRetryAfter = response.value(forHTTPHeaderField: "Retry-After")?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  !rawRetryAfter.isEmpty else {
                return initialRetryDelay
            }

            let retryAfterSeconds: TimeInterval?
            if let seconds = TimeInterval(rawRetryAfter) {
                retryAfterSeconds = seconds
            } else {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss z"
                retryAfterSeconds = formatter.date(from: rawRetryAfter)?
                    .timeIntervalSinceNow
            }

            guard let retryAfterSeconds else { return initialRetryDelay }
            let boundedMilliseconds = Int64(
                (min(max(retryAfterSeconds, 0), 5) * 1_000).rounded()
            )
            return .milliseconds(boundedMilliseconds)
        }
    }

    private enum InfoKey {
        static let stagingBaseURL = "TRAIBackendStagingBaseURL"
        static let productionBaseURL = "TRAIBackendProductionBaseURL"
    }

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(Self.encodeBackendDate(date))
        }
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()

            if let stringValue = try? container.decode(String.self),
               let date = Self.decodeBackendDate(stringValue) {
                return date
            }

            if let timestamp = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: timestamp)
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected an ISO-8601 date string in backend response."
            )
        }
        self.decoder = decoder
    }

    func baseURL(for environment: BackendEnvironment, customBackendBaseURL: String? = nil) -> URL? {
        switch environment {
        case .localPlaceholder:
            return nil
        case .localDevelopment:
            if let customBackendBaseURL,
               !customBackendBaseURL.isEmpty,
               let url = URL(string: customBackendBaseURL) {
                return url
            }
            return URL(string: "http://127.0.0.1:8789")
        case .staging:
            return configuredURL(forInfoKey: InfoKey.stagingBaseURL, fallback: "https://staging-api.trai.app")
        case .production:
            return configuredURL(forInfoKey: InfoKey.productionBaseURL, fallback: "https://api.trai.app")
        }
    }

    func proxyURL(
        action: String,
        streaming: Bool,
        environment: BackendEnvironment,
        customBackendBaseURL: String? = nil
    ) throws -> URL {
        guard let baseURL = baseURL(for: environment, customBackendBaseURL: customBackendBaseURL) else {
            throw BackendClientError.environmentNotConfigured
        }

        let path = streaming ? "/v1/ai/stream" : "/v1/ai/generate"
        return baseURL.appending(path: path).appending(queryItems: [
            URLQueryItem(name: "action", value: action)
        ])
    }

    func exchangeAppleIdentity(
        _ requestBody: AppleIdentityExchangeRequest,
        environment: BackendEnvironment,
        customBackendBaseURL: String? = nil
    ) async throws -> BackendBootstrapResponse {
        try await send(
            path: "/v1/auth/apple/exchange",
            method: "POST",
            body: requestBody,
            environment: environment,
            customBackendBaseURL: customBackendBaseURL,
            accessToken: nil,
            appAccountToken: requestBody.appAccountToken
        )
    }

    func fetchBootstrap(
        session: BackendSessionSnapshot,
        accountSnapshot: AppAccountSnapshot
    ) async throws -> BackendBootstrapResponse {
        try await send(
            path: "/v1/account/bootstrap",
            method: "GET",
            body: Optional<String>.none,
            environment: accountSnapshot.backendEnvironment,
            customBackendBaseURL: accountSnapshot.customBackendBaseURL,
            accessToken: session.accessToken,
            appAccountToken: accountSnapshot.appAccountToken
        )
    }

    func refreshSession(
        refreshToken: String,
        accountSnapshot: AppAccountSnapshot
    ) async throws -> BackendBootstrapResponse {
        try await send(
            path: "/v1/auth/refresh",
            method: "POST",
            body: RefreshSessionRequest(
                refreshToken: refreshToken,
                appAccountToken: accountSnapshot.appAccountToken
            ),
            environment: accountSnapshot.backendEnvironment,
            customBackendBaseURL: accountSnapshot.customBackendBaseURL,
            accessToken: nil,
            appAccountToken: accountSnapshot.appAccountToken
        )
    }

    func deleteAccount(
        session: BackendSessionSnapshot,
        accountSnapshot: AppAccountSnapshot
    ) async throws -> DeleteAccountResponse {
        try await send(
            path: "/v1/account",
            method: "DELETE",
            body: Optional<String>.none,
            environment: accountSnapshot.backendEnvironment,
            customBackendBaseURL: accountSnapshot.customBackendBaseURL,
            accessToken: session.accessToken,
            appAccountToken: accountSnapshot.appAccountToken
        )
    }

    func syncStoreKitEntitlements(
        signedTransactions: [String],
        _ entitlements: [StoreKitEntitlementRecord],
        session: BackendSessionSnapshot,
        accountSnapshot: AppAccountSnapshot
    ) async throws -> BillingSyncPayload {
        try await send(
            path: "/v1/billing/sync-storekit",
            method: "POST",
            body: StoreKitEntitlementSyncRequest(
                signedTransactions: signedTransactions,
                entitlements: entitlements
            ),
            environment: accountSnapshot.backendEnvironment,
            customBackendBaseURL: accountSnapshot.customBackendBaseURL,
            accessToken: session.accessToken,
            appAccountToken: accountSnapshot.appAccountToken
        )
    }

    private func send<T: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body?,
        environment: BackendEnvironment,
        customBackendBaseURL: String? = nil,
        accessToken: String?,
        appAccountToken: String
    ) async throws -> T {
        guard let baseURL = baseURL(for: environment, customBackendBaseURL: customBackendBaseURL) else {
            throw BackendClientError.environmentNotConfigured
        }

        let url = baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = RequestPolicy.timeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(appAccountToken, forHTTPHeaderField: "X-Trai-App-Account-Token")

        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            guard let data = try? encoder.encode(body) else {
                throw BackendClientError.encodingFailure
            }
            request.httpBody = data
        }

        let maximumAttempts = method == "GET" ? RequestPolicy.maximumReadAttempts : 1
        var attempt = 0
        var data = Data()
        var httpResponse: HTTPURLResponse?

        while attempt < maximumAttempts {
            attempt += 1
            var retryDelay = RequestPolicy.initialRetryDelay

            do {
                let (responseData, response) = try await session.data(for: request)
                guard let response = response as? HTTPURLResponse else {
                    throw BackendClientError.invalidResponse
                }

                data = responseData
                httpResponse = response

                let shouldRetryResponse = attempt < maximumAttempts
                    && RequestPolicy.shouldRetry(statusCode: response.statusCode)
                guard shouldRetryResponse else { break }
                retryDelay = RequestPolicy.retryDelay(for: response)
            } catch {
                let shouldRetryTransport = attempt < maximumAttempts
                    && RequestPolicy.shouldRetry(error: error)
                guard shouldRetryTransport else { throw error }
            }

            try await Task.sleep(for: retryDelay)
        }

        guard let httpResponse else {
            throw BackendClientError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            break
        case 401:
            throw BackendClientError.unauthorized
        default:
            let backendError = try? decoder.decode(BackendErrorPayload.self, from: data)
            let rawMessage = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let message = backendError?.message
                ?? rawMessage.flatMap { $0.isEmpty ? nil : $0 }
                ?? "Unknown backend error."
            throw BackendClientError.serverError(
                statusCode: httpResponse.statusCode,
                code: backendError?.error,
                message: message
            )
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw BackendClientError.invalidResponse
        }
    }

    private static func encodeBackendDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private func configuredURL(forInfoKey key: String, fallback: String) -> URL? {
        if let configuredValue = Bundle.main.object(forInfoDictionaryKey: key) as? String,
           let url = URL(string: configuredValue),
           !configuredValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return url
        }
        return URL(string: fallback)
    }

    private static func decodeBackendDate(_ string: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: string) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
