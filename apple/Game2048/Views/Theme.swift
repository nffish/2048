import SwiftUI

// Glazed ceramic palette from the web version: celadon → teal → amber → plum.

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: opacity
        )
    }
}

struct Palette {
    var background: Color
    var foreground: Color
    var muted: Color
    var board: Color
    var cell: Color
    var panel: Color
    var accent: Color
    var accentForeground: Color
    var shadow: Color
    var overlay: Color
    private var low: [Int: (Color, Color)]
    private var superTile: (Color, Color)

    static let light = Palette(
        background: Color(hex: 0xe9eef2), foreground: Color(hex: 0x1c2733), muted: Color(hex: 0x5d6b79),
        board: Color(hex: 0xb6c3cf), cell: Color(hex: 0xcdd7e0), panel: Color(hex: 0xd6dee6),
        accent: Color(hex: 0x1f7a8c), accentForeground: .white,
        shadow: Color(hex: 0x1c2733, opacity: 0.18), overlay: Color(hex: 0xe9eef2, opacity: 0.82),
        low: [2: (Color(hex: 0xf8fafb), Color(hex: 0x33414f)), 4: (Color(hex: 0xe1ebf0), Color(hex: 0x33414f))],
        superTile: (Color(hex: 0x1d2333), Color(hex: 0xf3c552))
    )

    static let dark = Palette(
        background: Color(hex: 0x11161c), foreground: Color(hex: 0xe4ebf1), muted: Color(hex: 0x8b99a7),
        board: Color(hex: 0x1e2731), cell: Color(hex: 0x2a3541), panel: Color(hex: 0x1e2731),
        accent: Color(hex: 0x3fb3b0), accentForeground: Color(hex: 0x0d1a1c),
        shadow: Color(hex: 0x000000, opacity: 0.45), overlay: Color(hex: 0x11161c, opacity: 0.84),
        low: [2: (Color(hex: 0x3a4757), Color(hex: 0xe4ebf1)), 4: (Color(hex: 0x4b5a6c), Color(hex: 0xeef3f7))],
        superTile: (Color(hex: 0xe4ebf1), Color(hex: 0x7d2e6c))
    )

    static func of(_ scheme: ColorScheme) -> Palette { scheme == .dark ? .dark : .light }

    private static let shared: [Int: (Color, Color)] = [
        8: (Color(hex: 0xa6d8cc), Color(hex: 0x173a35)),
        16: (Color(hex: 0x66bdab), .white),
        32: (Color(hex: 0x349f9b), .white),
        64: (Color(hex: 0x1f7a8c), .white),
        128: (Color(hex: 0xf3c552), Color(hex: 0x3b2a05)),
        256: (Color(hex: 0xf0a43c), Color(hex: 0x3b2205)),
        512: (Color(hex: 0xe6793b), .white),
        1024: (Color(hex: 0xd4524e), .white),
        2048: (Color(hex: 0x7d2e6c), Color(hex: 0xffe9a8)),
    ]

    /// Background and text colour for a tile value.
    func tile(_ value: Int) -> (background: Color, foreground: Color) {
        if value > Game.winValue { return superTile }
        return low[value] ?? Self.shared[value] ?? superTile
    }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette.light
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

extension Font {
    /// Stand-in for the web version's Unbounded display face.
    static func display(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
