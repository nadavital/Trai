import SwiftUI

/// Horizontal content may draw through the surrounding horizontal inset while its
/// first item retains the caller's alignment. Explicit enclosing card clips still apply.
/// Vertical page layout and safe areas remain owned by the surrounding screen.
struct TraiHorizontalScrollView<Content: View>: View {
    var identifier = "horizontalContentScroll"
    var allowsHorizontalOverflow = true
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView(.horizontal) { content }
            .scrollIndicators(.hidden)
            .scrollClipDisabled(allowsHorizontalOverflow)
            .contentMargins(.trailing, 16, for: .scrollContent)
            .scrollBounceBehavior(.basedOnSize, axes: [.horizontal, .vertical])
            .accessibilityIdentifier(identifier)
    }
}

/// Keep a vertical scroll viewport's top and bottom clipped while permitting its
/// horizontal descendants to render through page insets. Expansion is relative
/// to this viewport, not a device width or a layout offset; content layout and
/// safe-area insets are unchanged. Explicit card clips continue to own their bounds.
private struct TraiVerticalViewportClip: Shape {
    func path(in rect: CGRect) -> Path {
        Path(rect.insetBy(dx: -rect.width, dy: 0))
    }
}

extension View {
    func traiHorizontalOverflowViewport() -> some View {
        scrollClipDisabled()
            .clipShape(TraiVerticalViewportClip())
    }
}
