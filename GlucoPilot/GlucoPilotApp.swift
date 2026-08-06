import SwiftUI

@main
struct GlucoPilotApp: App {
    init() {
        // Ici, et pas dans une vue : quand iOS relance l'app en tâche de fond
        // après un déplacement, aucune scène n'est garantie. C'est pourtant
        // exactement le moment où il faut décider si un trajet commence.
        Task { @MainActor in
            TripController.shared.startIfConfigured()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
