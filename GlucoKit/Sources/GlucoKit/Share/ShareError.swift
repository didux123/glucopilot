import Foundation

/// Erreurs de l'API Dexcom Share.
public enum ShareError: Error, Sendable, Equatable {
    /// Dexcom a explicitement rejeté le compte ou le mot de passe.
    ///
    /// **Fatal** : ne jamais réessayer automatiquement. Un compte Dexcom se
    /// verrouille au bout de quelques tentatives, et l'utilisateur perdrait
    /// l'accès à sa propre glycémie sur l'app officielle.
    case credentialsRejected
    /// La session a expiré. Un — et un seul — re-login est autorisé.
    case sessionExpired
    /// Réseau indisponible, DNS, TLS, timeout.
    case unreachable
    /// Réponse HTTP inattendue.
    case http(status: Int)
    /// Corps de réponse illisible.
    case malformedResponse

    /// Vrai pour les erreurs qui doivent figer l'app jusqu'à intervention
    /// humaine.
    public var isFatal: Bool { self == .credentialsRejected }
}

extension ShareError {
    /// Classe une réponse d'erreur à partir de son corps brut.
    ///
    /// On raisonne par sous-chaînes plutôt que par décodage strict, comme le
    /// firmware (`isCredentialError` / `isSessionError`, main.cpp:444) : c'est
    /// ce qui a tenu en production, et Dexcom fait varier l'enrobage JSON de
    /// ses codes d'erreur.
    /// En cas de doute, on penche vers `credentialsRejected` : le pire scénario
    /// n'est pas de figer l'app à tort, c'est de continuer à taper sur un
    /// serveur qui refuse — et de verrouiller le compte.
    ///
    /// Dexcom nomme ses codes tantôt `...PasswordInvalid`, tantôt
    /// `...InvalidPassword`, avec ou sans préfixe `SSO_Authenticate` : on
    /// couvre les deux ordres plutôt que d'énumérer des codes exacts.
    static func classify(body: String, status: Int) -> ShareError {
        let credentialFragments = [
            "AccountPassword",
            "PasswordInvalid",
            "InvalidPassword",
            "AccountNotFound",
            "AccountLoginSuspended",
            "AccountDisabled",
            "MaxAttemptsExceeded",
        ]
        if credentialFragments.contains(where: body.contains) { return .credentialsRejected }

        let sessionCodes = ["SessionIdNotFound", "SessionNotValid"]
        if sessionCodes.contains(where: body.contains) { return .sessionExpired }

        return .http(status: status)
    }
}
