import SwiftUI
import WidgetKit

@main
struct GlucoPilotWidgetsBundle: WidgetBundle {
    var body: some Widget {
        GlucoseWidget()
        GlucoseLiveActivity()
    }
}
