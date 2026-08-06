import Foundation
import Security

/// Les identifiants Dexcom, dans le Trousseau — et nulle part ailleurs.
///
/// Leçon de la veilleuse : jamais d'identifiants dans le dépôt ni dans le
/// binaire. Ils sont saisis par l'utilisateur au premier lancement.
///
/// L'accessibilité est **`kSecAttrAccessibleAfterFirstUnlock`**, et ce n'est pas
/// négociable : en voiture le téléphone est verrouillé, et un widget qui dépend
/// d'une classe de protection plus stricte ne peut tout simplement pas
/// fonctionner en CarPlay.
///
/// Le partage app ↔ extension repose sur l'entitlement
/// `keychain-access-groups` : les deux cibles déclarent le **même groupe en
/// premier**, donc aucun `kSecAttrAccessGroup` n'est passé ici — iOS range
/// l'élément dans le premier groupe déclaré.
public struct CredentialStore: Sendable {
    private let service: String
    private let account: String

    public init(
        service: String = "com.didux.glucopilot.dexcom",
        account: String = "shareAccount"
    ) {
        self.service = service
        self.account = account
    }

    public static let shared = CredentialStore()

    private struct Payload: Codable {
        let accountName: String
        let password: String
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    public func load() -> ShareCredentials? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else { return nil }

        return ShareCredentials(
            accountName: payload.accountName,
            password: payload.password
        )
    }

    @discardableResult
    public func save(_ credentials: ShareCredentials) -> Bool {
        guard let data = try? JSONEncoder().encode(
            Payload(accountName: credentials.accountName, password: credentials.password)
        ) else { return false }

        // Remplacement systématique : plus simple et plus sûr qu'un update
        // conditionnel, et ça garantit la bonne accessibilité même si un
        // ancien élément traînait avec une autre classe de protection.
        SecItemDelete(baseQuery as CFDictionary)

        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    public func delete() -> Bool {
        let status = SecItemDelete(baseQuery as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
