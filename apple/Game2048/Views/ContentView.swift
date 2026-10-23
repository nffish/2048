import SwiftUI

struct ContentView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focused: Bool

    var body: some View {
        let palette = Palette.of(colorScheme)
        GeometryReader { geo in
            // Board fits the narrower of: the width, a 500pt cap, or the height left after the header and ladder.
            let column = max(240, min(500, geo.size.width - 32, geo.size.height - 290))
            ScrollView {
                VStack(spacing: 18) {
                    header
                    controls
                    BoardView()
                        .frame(width: column, height: column)
                        .contentShape(Rectangle())
                        .gesture(swipe)
                    TileLadder(maxTile: store.game.maxTile)
                    Text(helpText)
                        .font(.footnote)
                        .foregroundStyle(palette.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(width: column)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDisabled(geo.size.height > column + 290)
        }
        .background(palette.background.ignoresSafeArea())
        .foregroundStyle(palette.foreground)
        .tint(palette.accent)
        .environment(\.palette, palette)
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear { focused = true }
        .onKeyPress(phases: [.down, .repeat], action: handleKey)
        .sensoryFeedback(.impact(weight: .light), trigger: store.moveCount)
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 640)
        #endif
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            Text("20\(Text("48").foregroundColor(Palette.of(colorScheme).accent))")
                .font(.display(64))
                .kerning(-2.5)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .accessibilityLabel("2048")
            Spacer(minLength: 12)
            HStack(spacing: 8) {
                ScoreBox(label: "分数", value: store.game.score, gain: store.lastGain)
                ScoreBox(label: "最高", value: store.best, gain: nil)
            }
        }
    }

    private var controls: some View {
        HStack {
            Text("合并相同数字，拼出 \(Text("2048").bold())。")
                .foregroundStyle(Palette.of(colorScheme).muted)
                .lineLimit(2)
            Spacer(minLength: 8)
            Button("撤销") { store.undo(animated: !reduceMotion) }
                .buttonStyle(PillButtonStyle())
                .disabled(!store.game.canUndo)
            Button("新游戏") { store.newGame() }
                .buttonStyle(PillButtonStyle(primary: true))
        }
    }

    private var helpText: String {
        #if os(macOS)
        "方向键或 W A S D 移动，Z 或 ⌘Z 撤销，⌘N 新游戏。也可以用鼠标或触控板在棋盘上拖动。"
        #else
        "在棋盘上滑动来移动方块。连接键盘时，方向键或 W A S D 也可以移动，Z 撤销。"
        #endif
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let dx = value.translation.width, dy = value.translation.height
                let direction: Direction = abs(dx) > abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .down : .up)
                store.move(direction, animated: !reduceMotion)
            }
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        guard press.modifiers.isDisjoint(with: [.command, .control, .option]) else { return .ignored }
        let direction: Direction?
        switch press.key {
        case .upArrow: direction = .up
        case .downArrow: direction = .down
        case .leftArrow: direction = .left
        case .rightArrow: direction = .right
        default:
            switch press.characters.lowercased() {
            case "w": direction = .up
            case "s": direction = .down
            case "a": direction = .left
            case "d": direction = .right
            case "z":
                store.undo(animated: !reduceMotion)
                return .handled
            default: return .ignored
            }
        }
        if let direction { store.move(direction, animated: !reduceMotion) }
        return .handled
    }
}

struct ScoreBox: View {
    let label: LocalizedStringKey
    let value: Int
    let gain: GameStore.Gain?
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .kerning(1.5)
                .foregroundStyle(palette.muted)
            Text(String(value))
                .font(.display(22, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(value)))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .frame(minWidth: 82)
        .background(palette.panel, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(alignment: .top) {
            if let gain, !reduceMotion {
                FloatingGain(amount: gain.amount).id(gain.id)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The "+points" that drifts up out of the score box after a merge.
struct FloatingGain: View {
    let amount: Int
    @State private var gone = false
    @Environment(\.palette) private var palette

    var body: some View {
        Text("+\(amount)")
            .font(.display(15, weight: .bold))
            .foregroundStyle(palette.accent)
            .offset(y: gone ? -30 : 4)
            .opacity(gone ? 0 : 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                withAnimation(.easeOut(duration: 0.7)) { gone = true }
            }
    }
}

/// One swatch per power of two up to 2048, lit once reached.
struct TileLadder: View {
    let maxTile: Int
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("已解锁")
                Spacer()
                Text("当前最大 \(Text(String(maxTile)).font(.display(12, weight: .bold)).foregroundColor(palette.foreground))")
            }
            .font(.caption)
            .foregroundStyle(palette.muted)

            HStack(spacing: 4) {
                ForEach(1...11, id: \.self) { p in
                    let value = 1 << p
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(palette.tile(value).background)
                        .aspectRatio(1, contentMode: .fit)
                        .opacity(value <= maxTile ? 1 : 0.22)
                        .animation(.easeOut(duration: 0.3), value: maxTile)
                }
            }
            .accessibilityHidden(true)
        }
    }
}

struct PillButtonStyle: ButtonStyle {
    var primary = false
    @Environment(\.palette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .foregroundStyle(primary ? palette.accentForeground : palette.foreground)
            .background(primary ? palette.accent : palette.panel, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .opacity(isEnabled ? 1 : 0.45)
            .offset(y: configuration.isPressed ? 1 : 0)
            .brightness(configuration.isPressed ? 0.04 : 0)
            .contentShape(Rectangle())
    }
}

#Preview {
    ContentView()
        .environment(GameStore(defaults: UserDefaults(suiteName: "preview")!))
}
