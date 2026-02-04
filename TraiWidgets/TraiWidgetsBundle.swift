//
//  TraiWidgetsBundle.swift
//  TraiWidgets
//
//  Created by Nadav Avital on 1/20/26.
//

import SwiftUI
import WidgetKit

@main
struct TraiWidgetsBundle: WidgetBundle {
    var body: some Widget {
        // Home Screen Widgets
        TraiWidgets()

        // Lock Screen Widgets
        CalorieCircularWidget()
        StatsRectangularWidget()
        StatsInlineWidget()

        // Control Center Widget
        TraiWidgetsControl()

        // Live Activity
        TraiWidgetsLiveActivity()
    }
}
