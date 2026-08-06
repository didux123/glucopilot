import GlucoKit
import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model

    @State private var accountName = ""
    @State private var password = ""
    @State private var region: ShareRegion = .outsideUS
    @State private var isConnecting = false
    @State private var message: Message?

    private enum Message: Equatable {
        case rejected
        case undetermined

        var text: String {
            switch self {
            case .rejected:
                "Dexcom a refusé ces identifiants. Vérifiez-les dans l'app Dexcom avant de réessayer."
            case .undetermined:
                "Impossible de joindre Dexcom. Réessayez quand vous aurez du réseau."
            }
        }
    }

    private var canSubmit: Bool {
        !accountName.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
            && !isConnecting
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Adresse e-mail", text: $accountName)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Mot de passe", text: $password)
                        .textContentType(.password)
                    Picker("Région du compte", selection: $region) {
                        ForEach(ShareRegion.allCases, id: \.self) { region in
                            Text(region.label).tag(region)
                        }
                    }
                } header: {
                    Text("Compte Dexcom Share")
                } footer: {
                    Text(
                        """
                        Le même compte que l'application Dexcom. \
                        Vos identifiants restent dans le Trousseau de votre \
                        iPhone : ils ne sont envoyés qu'à Dexcom.
                        """
                    )
                }

                if let message {
                    Section {
                        Label(message.text, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(message == .rejected ? .red : .orange)
                    }
                }

                Section {
                    Button {
                        Task { await connect() }
                    } label: {
                        HStack {
                            Text("Se connecter")
                            Spacer()
                            if isConnecting { ProgressView() }
                        }
                    }
                    .disabled(!canSubmit)
                } footer: {
                    // Ce n'est pas une précaution de façade : un compte Dexcom
                    // se verrouille au bout de quelques tentatives ratées, et
                    // c'est le compte qui affiche la glycémie sur l'app
                    // officielle.
                    Text(
                        """
                        GlucoPilot ne fait qu'une seule tentative par appui, \
                        pour ne pas risquer de verrouiller votre compte Dexcom.
                        """
                    )
                }
            }
            .navigationTitle("GlucoPilot")
            .safeAreaInset(edge: .bottom) { disclaimer }
        }
    }

    private var disclaimer: some View {
        Text("GlucoPilot n'est pas un dispositif médical.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(.bar)
    }

    private func connect() async {
        isConnecting = true
        message = nil
        defer { isConnecting = false }

        switch await model.signIn(accountName: accountName, password: password, region: region) {
        case .success:
            password = ""
        case .rejected:
            message = .rejected
        case .undetermined:
            message = .undetermined
        }
    }
}
