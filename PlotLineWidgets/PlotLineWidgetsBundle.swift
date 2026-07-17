import ActivityKit
import WidgetKit
import SwiftUI

/// The widget bundle for the PlotLine extension. Currently hosts the "now watching"
/// Live Activity (Dynamic Island + Lock Screen). Add Home Screen widgets here later.
@main
struct PlotLineWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WatchLiveActivity()
    }
}
