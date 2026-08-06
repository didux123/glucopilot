import GlucoKit
import SwiftUI

struct RootView: View {
    @State private var model = AppModel()

    var body: some View {
        content
            .environment(model)
            .task { await model.start() }
            .task { await model.runForegroundLoop() }
    }

    @ViewBuilder
    private var content: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-gallery") {
            NavigationStack { WidgetGalleryView() }
        } else {
            main
        }
        #else
        main
        #endif
    }

    @ViewBuilder
    private var main: some View {
        if model.isSignedIn {
            DashboardView()
        } else {
            OnboardingView()
        }
    }
}
