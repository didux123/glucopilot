import Foundation

/// Couche transport injectable, pour que les tests n'appellent jamais Dexcom
/// pour de vrai — le compte se verrouille au bout de quelques tentatives.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

extension URLSession: HTTPTransport {
    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ShareError.malformedResponse
        }
        return (data, http)
    }
}

extension URLSession {
    /// Session dédiée à Dexcom : délais courts, pas de cache. En voiture on
    /// préfère un échec net et un nouvel essai au cycle suivant plutôt qu'une
    /// requête qui traîne et retient l'app éveillée.
    public static let dexcomShare: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = false
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        return URLSession(configuration: config)
    }()
}
