import Foundation
import Testing
@testable import GlucoKit

/// Le test le plus important du paquet.
///
/// Un compte Dexcom se verrouille au bout de quelques tentatives ratées, et
/// c'est le compte qui affiche la glycémie sur l'app officielle. Toute
/// régression ici a une conséquence médicale réelle, pas seulement logicielle.
@Suite("Session Dexcom — règle anti-verrouillage")
struct ShareSessionTests {
    private func session(_ transport: MockTransport) -> ShareSession {
        ShareSession(region: .outsideUS, transport: transport, store: InMemorySessionStore())
    }

    @Test("Cycle nominal : une authentification, une connexion, une lecture")
    func nominalCycle() async throws {
        let transport = MockTransport { path, _ in
            switch path {
            case let p where p.hasSuffix(Endpoint.authenticate): (200, Fixture.accountID)
            case let p where p.hasSuffix(Endpoint.login): (200, Fixture.sessionID)
            default: (200, Fixture.readings())
            }
        }
        let session = session(transport)
        let readings = try await session.fetch(credentials: Fixture.credentials)

        #expect(readings.count == 2)
        #expect(transport.count(endingWith: Endpoint.authenticate) == 1)
        #expect(transport.count(endingWith: Endpoint.login) == 1)
        #expect(transport.count(endingWith: Endpoint.read) == 1)
    }

    @Test("La session est réutilisée : pas de ré-authentification au cycle suivant")
    func reusesSession() async throws {
        let transport = MockTransport { path, _ in
            switch path {
            case let p where p.hasSuffix(Endpoint.authenticate): (200, Fixture.accountID)
            case let p where p.hasSuffix(Endpoint.login): (200, Fixture.sessionID)
            default: (200, Fixture.readings())
            }
        }
        let session = session(transport)
        _ = try await session.fetch(credentials: Fixture.credentials)
        _ = try await session.fetch(credentials: Fixture.credentials)
        _ = try await session.fetch(credentials: Fixture.credentials)

        // Trois lectures, mais une seule authentification : c'est ce qui évite
        // de marteler le compte à chaque réveil du widget.
        #expect(transport.count(endingWith: Endpoint.read) == 3)
        #expect(transport.count(endingWith: Endpoint.authenticate) == 1)
        #expect(transport.count(endingWith: Endpoint.login) == 1)
    }

    @Test("Session expirée : exactement un re-login, puis on repart")
    func singleRelogin() async throws {
        let transport = MockTransport { path, priorCalls in
            switch path {
            case let p where p.hasSuffix(Endpoint.authenticate): (200, Fixture.accountID)
            case let p where p.hasSuffix(Endpoint.login): (200, Fixture.sessionID)
            default:
                // La première lecture tombe sur une session expirée, la seconde
                // aboutit.
                priorCalls == 0
                    ? (500, Fixture.sessionExpired)
                    : (200, Fixture.readings())
            }
        }
        let session = session(transport)
        let readings = try await session.fetch(credentials: Fixture.credentials)

        #expect(readings.count == 2)
        #expect(transport.count(endingWith: Endpoint.authenticate) == 1)
        #expect(transport.count(endingWith: Endpoint.login) == 2)
        #expect(transport.count(endingWith: Endpoint.read) == 2)
    }

    @Test("Session expirée deux fois de suite : l'erreur remonte, aucune boucle")
    func neverLoops() async throws {
        let transport = MockTransport { path, _ in
            switch path {
            case let p where p.hasSuffix(Endpoint.authenticate): (200, Fixture.accountID)
            case let p where p.hasSuffix(Endpoint.login): (200, Fixture.sessionID)
            default: (500, Fixture.sessionExpired)  // toujours expirée
            }
        }
        let session = session(transport)

        await #expect(throws: ShareError.sessionExpired) {
            try await session.fetch(credentials: Fixture.credentials)
        }

        // Le plafond absolu : deux connexions et deux lectures, jamais plus.
        #expect(transport.count(endingWith: Endpoint.login) == 2)
        #expect(transport.count(endingWith: Endpoint.read) == 2)
    }

    @Test("Identifiants refusés à l'authentification : arrêt total")
    func rejectedAtAuthenticateStopsEverything() async throws {
        let transport = MockTransport { path, _ in
            path.hasSuffix(Endpoint.authenticate)
                ? (500, Fixture.credentialsRejected)
                : (200, "[]")
        }
        let session = session(transport)

        await #expect(throws: ShareError.credentialsRejected) {
            try await session.fetch(credentials: Fixture.credentials)
        }
        #expect(transport.count(endingWith: Endpoint.authenticate) == 1)

        // Les cycles suivants ne doivent émettre AUCUNE requête : c'est là que
        // se joue le verrouillage du compte.
        for _ in 0..<5 {
            await #expect(throws: ShareError.credentialsRejected) {
                try await session.fetch(credentials: Fixture.credentials)
            }
        }
        #expect(transport.paths.count == 1)
        #expect(await session.isBlocked)
    }

    @Test("Identifiants refusés à la connexion : arrêt total également")
    func rejectedAtLoginStopsEverything() async throws {
        let transport = MockTransport { path, _ in
            switch path {
            case let p where p.hasSuffix(Endpoint.authenticate): (200, Fixture.accountID)
            case let p where p.hasSuffix(Endpoint.login): (500, Fixture.credentialsRejected)
            default: (200, "[]")
            }
        }
        let session = session(transport)

        await #expect(throws: ShareError.credentialsRejected) {
            try await session.fetch(credentials: Fixture.credentials)
        }
        let callsBefore = transport.paths.count

        await #expect(throws: ShareError.credentialsRejected) {
            try await session.fetch(credentials: Fixture.credentials)
        }
        #expect(transport.paths.count == callsBefore)
    }

    @Test("Le GUID nul renvoyé par Dexcom vaut un refus")
    func nullGUIDIsARejection() async throws {
        let transport = MockTransport { path, _ in
            switch path {
            case let p where p.hasSuffix(Endpoint.authenticate): (200, Fixture.accountID)
            case let p where p.hasSuffix(Endpoint.login):
                (200, "\"00000000-0000-0000-0000-000000000000\"")
            default: (200, "[]")
            }
        }
        let session = session(transport)

        await #expect(throws: ShareError.credentialsRejected) {
            try await session.fetch(credentials: Fixture.credentials)
        }
        #expect(await session.isBlocked)
    }

    @Test("Une erreur réseau ne bloque pas le compte — elle est réessayable")
    func networkErrorIsNotFatal() async throws {
        let transport = MockTransport { _, _ in (503, "Service Unavailable") }
        let session = session(transport)

        await #expect(throws: ShareError.http(status: 503)) {
            try await session.fetch(credentials: Fixture.credentials)
        }
        #expect(await session.isBlocked == false)
    }

    @Test("Changer de compte lève le blocage et repart sur une session neuve")
    func changingAccountClearsTheBlock() async throws {
        let transport = MockTransport { path, priorCalls in
            switch path {
            case let p where p.hasSuffix(Endpoint.authenticate):
                // Le premier compte est refusé, le second accepté.
                priorCalls == 0
                    ? (500, Fixture.credentialsRejected)
                    : (200, Fixture.accountID)
            case let p where p.hasSuffix(Endpoint.login): (200, Fixture.sessionID)
            default: (200, Fixture.readings())
            }
        }
        let session = session(transport)

        await #expect(throws: ShareError.credentialsRejected) {
            try await session.fetch(credentials: Fixture.credentials)
        }

        let other = ShareCredentials(accountName: "autre@example.com", password: "x")
        let readings = try await session.fetch(credentials: other)
        #expect(readings.count == 2)
        #expect(await session.isBlocked == false)
    }

    @Test("reset() débloque après correction manuelle des identifiants")
    func resetUnblocks() async throws {
        let transport = MockTransport { path, priorCalls in
            switch path {
            case let p where p.hasSuffix(Endpoint.authenticate):
                priorCalls == 0
                    ? (500, Fixture.credentialsRejected)
                    : (200, Fixture.accountID)
            case let p where p.hasSuffix(Endpoint.login): (200, Fixture.sessionID)
            default: (200, Fixture.readings())
            }
        }
        let session = session(transport)

        await #expect(throws: ShareError.credentialsRejected) {
            try await session.fetch(credentials: Fixture.credentials)
        }
        await session.reset()
        #expect(try await session.fetch(credentials: Fixture.credentials).count == 2)
    }
}

@Suite("Validation des identifiants")
struct ShareValidationTests {
    @Test("Une seule tentative par appel")
    func singleAttempt() async throws {
        let transport = MockTransport { _, _ in (200, Fixture.accountID) }
        let session = ShareSession(
            region: .outsideUS, transport: transport, store: InMemorySessionStore()
        )
        #expect(try await session.validate(credentials: Fixture.credentials))
        #expect(transport.paths.count == 1)
    }

    @Test("Un refus renvoie false, sans exception")
    func rejectionReturnsFalse() async throws {
        let transport = MockTransport { _, _ in (500, Fixture.credentialsRejected) }
        let session = ShareSession(
            region: .outsideUS, transport: transport, store: InMemorySessionStore()
        )
        #expect(try await session.validate(credentials: Fixture.credentials) == false)
        #expect(transport.paths.count == 1)
    }

    @Test("Une panne réseau lève une erreur — « indéterminé » n'est pas « refusé »")
    func networkErrorThrowsInsteadOfReturningFalse() async {
        // Annoncer « mot de passe incorrect » sur une coupure réseau pousserait
        // l'utilisateur à retaper son mot de passe, donc à verrouiller son
        // compte. L'appelant doit pouvoir distinguer les deux cas.
        let transport = MockTransport { _, _ in (503, "Service Unavailable") }
        let session = ShareSession(
            region: .outsideUS, transport: transport, store: InMemorySessionStore()
        )
        await #expect(throws: ShareError.http(status: 503)) {
            try await session.validate(credentials: Fixture.credentials)
        }
    }
}
