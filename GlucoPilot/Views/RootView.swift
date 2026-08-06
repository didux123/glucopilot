import GlucoKit
import SwiftUI

struct RootView: View {
    @State private var model = AppModel()

    var body: some View {
        Group {
            if model.isSignedIn {
                DashboardView()
            } else {
                OnboardingView()
            }
        }
        .environment(model)
        .task { await model.start() }
        .task { await model.runForegroundLoop() }
    }
}
