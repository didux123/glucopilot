import Foundation

/// Client bas niveau de l'API Dexcom Share.
///
/// Transposition directe de `dexAuthenticate` / `dexLogin` / `dexFetch`
/// (main.cpp:458-520). Sans état : c'est `ShareSession` qui porte la logique de
/// session et la règle anti-verrouillage.
public struct ShareClient: Sendable {
    /// Identifiant d'application public de l'app Dexcom Share, utilisé par tous
    /// les clients tiers. Ce n'est pas un secret.
    static let applicationID = "d89443d2-327c-4a6f-89e5-496bbb0317db"
    static let userAgent = "Dexcom Share/3.0.2.11 CFNetwork/711.2.23 Darwin/14.0.0"

    let region: ShareRegion
    let transport: any HTTPTransport

    public init(region: ShareRegion, transport: any HTTPTransport = URLSession.dexcomShare) {
        self.region = region
        self.transport = transport
    }

    // MARK: - Étapes de l'API

    /// Étape 1 : e-mail + mot de passe → `accountId`.
    ///
    /// C'est l'étape qui rejette explicitement un mauvais mot de passe ; elle
    /// suffit donc à valider des identifiants (cf. `dexProbe`, main.cpp:528).
    public func authenticate(accountName: String, password: String) async throws -> String {
        let body: [String: String] = [
            "accountName": accountName,
            "password": password,
            "applicationId": Self.applicationID,
        ]
        let data = try await post(path: "/General/AuthenticatePublisherAccount", json: body)
        return try Self.guid(from: data)
    }

    /// Étape 2 : `accountId` + mot de passe → `sessionId`.
    public func login(accountID: String, password: String) async throws -> String {
        let body: [String: String] = [
            "accountId": accountID,
            "password": password,
            "applicationId": Self.applicationID,
        ]
        let data = try await post(path: "/General/LoginPublisherAccountById", json: body)
        let sessionID = try Self.guid(from: data)
        // Dexcom renvoie le GUID nul quand la session est refusée sans erreur
        // HTTP — le firmware traite ce cas comme des identifiants invalides.
        guard sessionID != "00000000-0000-0000-0000-000000000000" else {
            throw ShareError.credentialsRejected
        }
        return sessionID
    }

    /// Étape 3 : les mesures, de la plus récente à la plus ancienne.
    ///
    /// Un seul appel sert à la fois la valeur courante et la courbe : on
    /// demande 3 h par défaut, soit 36 mesures à raison d'une toutes les 5 min.
    public func readGlucose(
        sessionID: String,
        minutes: Int = 180,
        maxCount: Int = 36
    ) async throws -> [GlucoseReading] {
        var components = URLComponents(
            url: region.baseURL.appending(path: "/Publisher/ReadPublisherLatestGlucoseValues"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "sessionId", value: sessionID),
            URLQueryItem(name: "minutes", value: String(minutes)),
            URLQueryItem(name: "maxCount", value: String(maxCount)),
        ]
        guard let url = components?.url else { throw ShareError.malformedResponse }

        let data = try await send(request(url: url, body: Data()))
        let entries = try Self.decodeEntries(from: data)
        // Défensif : l'API trie déjà du plus récent au plus ancien, mais tout le
        // reste du code en dépend (delta, latest), autant le garantir ici.
        return entries.sorted { $0.date > $1.date }
    }

    // MARK: - HTTP

    private func post(path: String, json: [String: String]) async throws -> Data {
        let body = try JSONSerialization.data(withJSONObject: json)
        return try await send(request(url: region.baseURL.appending(path: path), body: body))
    }

    private func request(url: URL, body: Data) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch let error as ShareError {
            throw error
        } catch {
            throw ShareError.unreachable
        }

        guard response.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ShareError.classify(body: body, status: response.statusCode)
        }
        return data
    }

    // MARK: - Décodage

    /// Les étapes 1 et 2 renvoient un GUID comme unique chaîne JSON du corps.
    /// On extrait ce qui est entre guillemets, à l'image de `firstQuoted`
    /// (main.cpp:436) — plus tolérant qu'un décodage strict.
    static func guid(from data: Data) throws -> String {
        guard let raw = String(data: data, encoding: .utf8),
              let start = raw.firstIndex(of: "\""),
              let end = raw[raw.index(after: start)...].firstIndex(of: "\"")
        else { throw ShareError.malformedResponse }

        let guid = String(raw[raw.index(after: start)..<end])
        guard guid.count == 36 else { throw ShareError.malformedResponse }
        return guid
    }

    private struct Entry: Decodable {
        let wt: String
        let value: Int
        let trend: Trend

        enum CodingKeys: String, CodingKey {
            case wt = "WT"
            case value = "Value"
            case trend = "Trend"
        }
    }

    static func decodeEntries(from data: Data) throws -> [GlucoseReading] {
        let entries: [Entry]
        do {
            entries = try JSONDecoder().decode([Entry].self, from: data)
        } catch {
            throw ShareError.malformedResponse
        }
        return entries.compactMap { entry in
            guard let date = parseShareDate(entry.wt) else { return nil }
            return GlucoseReading(mgdl: entry.value, trend: entry.trend, date: date)
        }
    }

    /// `"Date(1426292016000)"` ou `"Date(1426292016000-0700)"` → `Date`.
    ///
    /// On lit le champ `WT` (world time, UTC) : les millisecondes qui suivent
    /// `Date(`, éventuel décalage de fuseau ignoré.
    static func parseShareDate(_ raw: String) -> Date? {
        guard let open = raw.firstIndex(of: "(") else { return nil }
        let digits = raw[raw.index(after: open)...].prefix { $0.isNumber }
        guard let milliseconds = Int64(digits), milliseconds > 0 else { return nil }
        return Date(timeIntervalSince1970: Double(milliseconds) / 1000)
    }
}
