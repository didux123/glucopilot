import AppIntents
import GlucoKit

/// « Dis Siri, ma glycémie » — réponse parlée dans les haut-parleurs de la
/// voiture, mains sur le volant.
///
/// Fonctionne dans CarPlay comme en dehors, sans entitlement ni configuration
/// préalable : c'est la surface la plus robuste des trois, celle qui reste
/// quand le Dashboard n'est pas affiché.
struct CurrentGlucoseIntent: AppIntent {
    static let title: LocalizedStringResource = "Ma glycémie"
    static let description = IntentDescription(
        "Annonce votre dernière glycémie, sa tendance et son âge."
    )
    /// Surtout pas : ouvrir l'app au volant serait exactement le contraire du
    /// but recherché.
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let snapshot = await GlucoseRefresher.shared.refresh()
        let summary = snapshot.spokenSummary()
        return .result(value: summary, dialog: IntentDialog("\(summary)"))
    }
}

/// Phrases proposées d'office, sans que l'utilisateur ait à créer un raccourci.
/// Apple impose que chaque phrase contienne le nom de l'app.
struct GlucoPilotShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CurrentGlucoseIntent(),
            phrases: [
                "Ma glycémie dans \(.applicationName)",
                "Quelle est ma glycémie dans \(.applicationName)",
                "Glycémie \(.applicationName)",
            ],
            shortTitle: "Ma glycémie",
            systemImageName: "drop.fill"
        )
    }
}
