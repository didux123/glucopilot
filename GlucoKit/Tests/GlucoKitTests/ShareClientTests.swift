import Foundation
import Testing
@testable import GlucoKit

@Suite("Client Dexcom Share")
struct ShareClientTests {
    @Test("Les serveurs correspondent à la région")
    func regionEndpoints() {
        #expect(ShareRegion.unitedStates.baseURL.host() == "share2.dexcom.com")
        #expect(ShareRegion.outsideUS.baseURL.host() == "shareous1.dexcom.com")
    }

    @Test("Le GUID est extrait du corps de réponse")
    func guidExtraction() throws {
        let guid = try ShareClient.guid(from: Data(Fixture.accountID.utf8))
        #expect(guid == "11111111-2222-3333-4444-555555555555")
    }

    @Test("Un GUID mal formé est rejeté")
    func rejectsMalformedGUID() {
        #expect(throws: ShareError.malformedResponse) {
            try ShareClient.guid(from: Data("\"trop-court\"".utf8))
        }
        #expect(throws: ShareError.malformedResponse) {
            try ShareClient.guid(from: Data("pas de guillemets".utf8))
        }
    }

    @Test("Le format de date Dexcom est décodé")
    func shareDateParsing() {
        #expect(
            ShareClient.parseShareDate("Date(1426292016000)")
                == Date(timeIntervalSince1970: 1_426_292_016)
        )
        // Le décalage de fuseau accolé est ignoré : WT est déjà en UTC.
        #expect(
            ShareClient.parseShareDate("Date(1426292016000-0700)")
                == Date(timeIntervalSince1970: 1_426_292_016)
        )
        #expect(ShareClient.parseShareDate("Date()") == nil)
        #expect(ShareClient.parseShareDate("n'importe quoi") == nil)
    }

    @Test("Les mesures sont décodées et triées du plus récent au plus ancien")
    func decodesReadings() async throws {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let transport = MockTransport { path, _ in
            if path.hasSuffix(Endpoint.read) {
                return (200, Fixture.readings(latest: 142, previous: 137, at: date))
            }
            return (200, "[]")
        }
        let client = ShareClient(region: .outsideUS, transport: transport)
        let readings = try await client.readGlucose(sessionID: "session")

        #expect(readings.count == 2)
        #expect(readings[0].mgdl == 142)
        #expect(readings[0].trend == .fortyFiveUp)
        #expect(readings[0].date == date)
        #expect(readings[1].mgdl == 137)
        #expect(readings[0].date > readings[1].date)
        #expect(readings.delta == 5)
    }

    @Test("Un tableau vide n'est pas une erreur — juste aucune mesure récente")
    func emptyResultIsNotAnError() async throws {
        let transport = MockTransport { _, _ in (200, "[]") }
        let client = ShareClient(region: .outsideUS, transport: transport)
        #expect(try await client.readGlucose(sessionID: "session").isEmpty)
    }

    @Test("La lecture demande bien 3 h de mesures en un seul appel")
    func readQueryParameters() async throws {
        let transport = MockTransport { _, _ in (200, "[]") }
        let client = ShareClient(region: .outsideUS, transport: transport)
        _ = try await client.readGlucose(sessionID: "abc")

        let url = try #require(transport.urls.first)
        let items = try #require(
            URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        )
        let params = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value) })
        #expect(params["sessionId"] == "abc")
        #expect(params["minutes"] == "180")
        #expect(params["maxCount"] == "36")
    }

    @Test("Un corps illisible est signalé comme tel")
    func malformedBody() async {
        let transport = MockTransport { _, _ in (200, "{ pas du json") }
        let client = ShareClient(region: .outsideUS, transport: transport)
        await #expect(throws: ShareError.malformedResponse) {
            try await client.readGlucose(sessionID: "session")
        }
    }
}

@Suite("Classement des erreurs Dexcom")
struct ShareErrorTests {
    @Test("Les codes d'identifiants sont fatals")
    func credentialCodes() {
        let codes = [
            "SSO_AuthenticatePasswordInvalid",
            "AccountPassword",
            "AccountNotFound",
            "InvalidPassword",
            "AccountLoginSuspended",
            "SSO_AuthenticateMaxAttemptsExceeded",
        ]
        for code in codes {
            let error = ShareError.classify(body: "{\"Code\":\"\(code)\"}", status: 500)
            #expect(error == .credentialsRejected, "\(code) doit être fatal")
            #expect(error.isFatal)
        }
    }

    @Test("Les codes de session autorisent un unique re-login")
    func sessionCodes() {
        for code in ["SessionIdNotFound", "SessionNotValid"] {
            let error = ShareError.classify(body: "{\"Code\":\"\(code)\"}", status: 500)
            #expect(error == .sessionExpired)
            #expect(!error.isFatal)
        }
    }

    @Test("Un code inconnu reste une erreur HTTP réessayable")
    func unknownCode() {
        let error = ShareError.classify(body: "{\"Code\":\"Boom\"}", status: 503)
        #expect(error == .http(status: 503))
        #expect(!error.isFatal)
    }
}
