import SwiftUI

/// A shallow scale with a recessed coral display; all details scale from the same geometry.
struct WeightScaleMark: View {
    let lit: Bool
    let weight: Double
    @Environment(\.colorScheme) private var scheme
    private var dark: Bool { scheme == .dark }
    private let coral = Color(red: 0.96, green: 0.34, blue: 0.35)

    var body: some View {
        GeometryReader { proxy in
            let unit = min(proxy.size.width / 160, proxy.size.height / 150)
            let tiny = proxy.size.width < 50
            ZStack {
                RoundedRectangle(cornerRadius: 32)
                    .fill(dark ? Color(white: 0.12) : Color(red: 0.72, green: 0.68, blue: 0.65))
                    .offset(y: 6)
                RoundedRectangle(cornerRadius: 32)
                    .fill(LinearGradient(colors: dark
                        ? [Color(white: 0.34), Color(white: 0.20)]
                        : [Color(red: 1, green: 0.98, blue: 0.93), Color(red: 0.89, green: 0.85, blue: 0.80)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay {
                        RoundedRectangle(cornerRadius: 32).strokeBorder(
                            LinearGradient(colors: [.white.opacity(dark ? 0.4 : 0.95), .white.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                    }
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11)
                            .fill(dark ? Color(white: 0.08) : Color(red: 0.37, green: 0.29, blue: 0.29))
                        RoundedRectangle(cornerRadius: 9)
                            .fill(coral.opacity(lit ? 0.35 : 0.08)).padding(2)
                        if tiny {
                            Capsule().fill(coral).frame(width: 35, height: 7)
                        } else {
                            Text(lit ? weight.formatted(.number.precision(.fractionLength(1))) : "– –")
                                .font(.system(size: 22, weight: .medium, design: .rounded))
                                .monospacedDigit().foregroundStyle(Color(red: 1, green: 0.64, blue: 0.57))
                        }
                    }.frame(width: 76, height: 37)
                    HStack(spacing: 27) {
                        pad
                        pad
                    }
                }.padding(.top, 1)
            }
            .frame(width: 144, height: 134)
            .rotation3DEffect(.degrees(18), axis: (x: 1, y: 0, z: 0), perspective: 0.3)
            .rotationEffect(.degrees(-9))
            .shadow(color: .black.opacity(dark ? 0.28 : 0.14), radius: 7, x: 0, y: 9)
            .scaleEffect(unit, anchor: .topLeading)
            .frame(width: 144 * unit, height: 134 * unit, alignment: .topLeading)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }.accessibilityHidden(true)
    }

    private var pad: some View {
        RoundedRectangle(cornerRadius: 11)
            .fill(.primary.opacity(dark ? 0.09 : 0.035))
            .overlay { RoundedRectangle(cornerRadius: 11).strokeBorder(.white.opacity(dark ? 0.08 : 0.45), lineWidth: 1) }
            .frame(width: 35, height: 42)
    }
}
