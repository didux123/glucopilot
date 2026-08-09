import GlucoKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var draft = GlucoSettings.default
    @State private var confirmsSignOut = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Seuils") {
                    stepper("Hypo", value: $draft.hypo, range: 50...100)
                    stepper("Hyper", value: $draft.hyper, range: 120...250)
                    stepper("Hyper sévère", value: $draft.hyperSevere, range: 200...400)
                }

                Section {
                    Toggle("Signaler l'hypo imminente", isOn: $draft.imminentHypoEnabled)
                    if draft.imminentHypoEnabled {
                        stepper(
                            "Seuil",
                            value: $draft.imminentHypoThreshold,
                            range: draft.hypo...draft.hyper
                        )
                    }
                } footer: {
                    Text(
                        """
                        Alerte quand la glycémie passe sous ce seuil **et** \
                        que la flèche descend franchement — avant que l'hypo \
                        ne soit atteinte.
                        """
                    )
                }

                Section {
                    LabeledContent("CarPlay") {
                        Text(TripController.shared.isCarPlayConnected ? "Connecté" : "Non connecté")
                            .foregroundStyle(.secondary)
                    }
                    if TripController.shared.isTripActive {
                        Button("Arrêter le trajet", role: .destructive) {
                            TripController.shared.stopTripManually()
                        }
                    } else {
                        Button("Démarrer le trajet maintenant") {
                            TripController.shared.startTripManually()
                        }
                    }
                } header: {
                    Text("Trajet")
                } footer: {
                    Text(
                        """
                        La Live Activity s'affiche sur le Dashboard CarPlay \
                        tant qu'un trajet est en cours — il n'y a rien à y \
                        ajouter. Elle démarre seule à la connexion CarPlay ; \
                        ce bouton sert quand la détection tarde, le réveil par \
                        déplacement pouvant prendre quelques centaines de \
                        mètres.
                        """
                    )
                }

                Section("Compte") {
                    if let accountName = model.accountName {
                        LabeledContent("Dexcom", value: accountName)
                    }
                    Picker("Région", selection: $draft.region) {
                        ForEach(ShareRegion.allCases, id: \.self) { region in
                            Text(region.label).tag(region)
                        }
                    }
                    Button("Se déconnecter", role: .destructive) { confirmsSignOut = true }
                }

                #if DEBUG
                Section("Développement") {
                    NavigationLink("Aperçu du widget") { WidgetGalleryView() }
                }
                #endif

                Section {
                    Text(
                        """
                        GlucoPilot n'est pas un dispositif médical. Ne prenez \
                        aucune décision de traitement sur la base de cet \
                        affichage : référez-vous à l'application Dexcom et à \
                        un contrôle capillaire.
                        """
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        Task {
                            await model.save(settings: draft)
                            dismiss()
                        }
                    }
                }
            }
            .onAppear { draft = model.settings }
            .confirmationDialog(
                "Se déconnecter de Dexcom ?",
                isPresented: $confirmsSignOut,
                titleVisibility: .visible
            ) {
                Button("Se déconnecter", role: .destructive) {
                    Task {
                        await model.signOut()
                        dismiss()
                    }
                }
            } message: {
                Text("Vos identifiants seront effacés du Trousseau de cet iPhone.")
            }
        }
    }

    private func stepper(
        _ title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>
    ) -> some View {
        Stepper(value: value, in: range, step: 5) {
            LabeledContent(title) {
                Text("\(value.wrappedValue) mg/dL").monospacedDigit()
            }
        }
    }
}
