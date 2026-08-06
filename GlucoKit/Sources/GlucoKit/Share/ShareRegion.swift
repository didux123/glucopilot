import Foundation

/// Région du compte Dexcom. Détermine le serveur Share à interroger
/// (main.cpp:228).
public enum ShareRegion: String, Sendable, Codable, Equatable, CaseIterable {
    /// États-Unis.
    case unitedStates = "us"
    /// Hors États-Unis — c'est le cas de la veilleuse.
    case outsideUS = "ous"

    public var label: String {
        switch self {
        case .unitedStates: "États-Unis"
        case .outsideUS: "Hors États-Unis"
        }
    }

    var baseURL: URL {
        switch self {
        case .unitedStates:
            URL(string: "https://share2.dexcom.com/ShareWebServices/Services")!
        case .outsideUS:
            URL(string: "https://shareous1.dexcom.com/ShareWebServices/Services")!
        }
    }
}
