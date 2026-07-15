import Foundation
import XCTest
@testable import Trai

final class TraiBackendClientRetryTests: XCTestCase {
    override func setUp() {
        super.setUp()
        BackendStubURLProtocol.reset()
    }

    override func tearDown() {
        BackendStubURLProtocol.reset()
        super.tearDown()
    }

    func testReadRetriesOnceAfterTransientServerFailure() async {
        BackendStubURLProtocol.enqueue(statusCodes: [503, 503])
        let (client, session) = makeClient()
        defer { session.invalidateAndCancel() }

        do {
            _ = try await client.fetchBootstrap(session: sessionSnapshot, accountSnapshot: accountSnapshot)
            XCTFail("Expected the final service-unavailable response to be surfaced.")
        } catch BackendClientError.serverError(let statusCode, _, _) {
            XCTAssertEqual(statusCode, 503)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(BackendStubURLProtocol.requestCount, 2)
        XCTAssertEqual(BackendStubURLProtocol.requests.first?.timeoutInterval, 30)
    }

    func testWriteDoesNotRetryAfterTransientServerFailure() async {
        BackendStubURLProtocol.enqueue(statusCodes: [503, 200])
        let (client, session) = makeClient()
        defer { session.invalidateAndCancel() }

        do {
            _ = try await client.deleteAccount(session: sessionSnapshot, accountSnapshot: accountSnapshot)
            XCTFail("Expected the service-unavailable response to be surfaced.")
        } catch BackendClientError.serverError(let statusCode, _, _) {
            XCTAssertEqual(statusCode, 503)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(BackendStubURLProtocol.requestCount, 1)
    }

    private func makeClient() -> (TraiBackendClient, URLSession) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [BackendStubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return (TraiBackendClient(session: session), session)
    }

    private var sessionSnapshot: BackendSessionSnapshot {
        BackendSessionSnapshot(
            userID: "user-test",
            identityProvider: .apple,
            email: nil,
            displayName: nil,
            accessToken: "access-test",
            refreshToken: nil,
            expiresAt: nil,
            lastAuthenticatedAt: .now
        )
    }

    private var accountSnapshot: AppAccountSnapshot {
        AppAccountSnapshot(
            installationID: "installation-test",
            appAccountToken: "account-test",
            identityMode: .signInWithApple,
            backendEnvironment: .localDevelopment,
            customBackendBaseURL: "https://backend.test",
            lastSyncedAt: nil
        )
    }
}

private final class BackendStubURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var pendingStatusCodes: [Int] = []
    nonisolated(unsafe) private static var capturedRequests: [URLRequest] = []

    static var requestCount: Int {
        lock.withLock { capturedRequests.count }
    }

    static var requests: [URLRequest] {
        lock.withLock { capturedRequests }
    }

    static func enqueue(statusCodes: [Int]) {
        lock.withLock {
            pendingStatusCodes = statusCodes
        }
    }

    static func reset() {
        lock.withLock {
            pendingStatusCodes = []
            capturedRequests = []
        }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let statusCode = Self.lock.withLock { () -> Int in
            Self.capturedRequests.append(request)
            guard !Self.pendingStatusCodes.isEmpty else { return 500 }
            return Self.pendingStatusCodes.removeFirst()
        }

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        let data = Data("{\"error\":\"stub_error\",\"message\":\"Stubbed backend failure\"}".utf8)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
