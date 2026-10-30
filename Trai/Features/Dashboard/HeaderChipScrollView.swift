import SwiftUI

/// Shared scrolling surface for the navigation chips above a page.
struct HeaderChipScrollView<Content: View>: View {
    let identifier: String
    @ViewBuilder var content: Content
    #if DEBUG
    @State private var verticalExcursion: CGFloat = 0
    #endif

    var body: some View {
        TraiHorizontalScrollView(identifier: identifier) { content }
            // The strip has no vertical overflow, so diagonal drags must not bounce it vertically.
            .scrollBounceBehavior(.basedOnSize, axes: [.horizontal, .vertical])
            .accessibilityIdentifier(identifier)
            #if DEBUG
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                if ProcessInfo.processInfo.arguments.contains("UITEST_MODE") {
                    verticalExcursion = max(verticalExcursion, abs(offset))
                }
            }
            .accessibilityValue(ProcessInfo.processInfo.arguments.contains("UITEST_MODE")
                ? String(format: "%.2f", verticalExcursion) : "")
            #endif
    }
}
