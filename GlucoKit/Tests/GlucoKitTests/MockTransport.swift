import Foundation
import Testing
@testable import GlucoKit

/// Transport bouchonné. **Aucun test de ce paquet n'appelle Dexcom pour de
/// vrai** : le compte se verrouille au bout de quelques tentatives, et ce
/// compte est celui qui affiche la glycémie sur l'app officielle.
final class MockTransport: HTTPTransport, @unchecked Sendable {
    typealias Handler = @Sendable (String, Int) -> (status: Int, body: String)

    private let handler: Handler
    private let lock = NSLock()
    private var recorded: [String] = []
    private var recordedURLs: [URL] = []

    /// - Parameter handler: reçoit le chemin de la requête et le nombre d'appels
    ///   déjà reçus sur ce chemin, renvoie le statut HTTP et le corps.
    init(handler: @escaping Handler) {
        self.handler = handler
    }

    var paths: [String] { lock.withLock { recorded } }

    var urls: [URL] { lock.withLock { recordedURLs } }

    func count(endingWith suffix: String) -> Int {
        paths.filter { $0.hasSuffix(suffix) }.count
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard let url = request.url else { throw ShareError.malformedResponse }
        let path = url.path(percentEncoded: false)

        let priorCalls = lock.withLock {
            let n = recorded.filter { $0 == path }.count
            recorded.append(path)
            recordedURLs.append(url)
            return n
        }

        let (status, body) = handler(path, priorCalls)
        let response = HTTPURLResponse(
            url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil
        )!
        return (Data(body.utf8), response)
    }
}

enum Endpoint {
    static let authenticate = "/General/AuthenticatePublisherAccount"
    static let login = "/General/LoginPublisherAccountById"
    static let read = "/Publisher/ReadPublisherLatestGlucoseValues"
}

enum Fixture {
    static let accountID = "\"11111111-2222-3333-4444-555555555555\""
    static let sessionID = "\"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee\""

    static let credentialsRejected = """
        {"Code":"SSO_AuthenticatePasswordInvalid","Message":"Publisher account password failed"}
        """
    static let sessionExpired = """
        {"Code":"SessionIdNotFound","Message":"Session ID not found"}
        """

    /// Deux mesures, la plus récente en premier, comme le fait l'API.
    static func readings(latest: Int = 142, previous: Int = 137, at date: Date = .now) -> String {
        let newest = Int64(date.timeIntervalSince1970 * 1000)
        let older = newest - 5 * 60 * 1000
        return """
            [{"WT":"Date(\(newest))","ST":"Date(\(newest))","DT":"Date(\(newest)+0100)",\
            "Value":\(latest),"Trend":"FortyFiveUp"},\
            {"WT":"Date(\(older))","ST":"Date(\(older))","DT":"Date(\(older)+0100)",\
            "Value":\(previous),"Trend":"Flat"}]
            """
    }

    static let credentials = ShareCredentials(accountName: "moi@example.com", password: "motdepasse")
}
