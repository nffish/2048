import SwiftUI

struct BoardView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let n = CGFloat(Game.size)
            let gap = side * 0.028
            let cell = (side - gap * (n + 1)) / n
            let radius = side * 0.032
            let origin = { (i: Int) in gap + CGFloat(i) * (cell + gap) }

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(palette.board)
                    .shadow(color: palette.shadow, radius: 15, y: 10)

                ForEach(0..<(Game.size * Game.size), id: \.self) { i in
                    RoundedRectangle(cornerRadius: side * 0.018, style: .continuous)
                        .fill(palette.cell)
                        .frame(width: cell, height: cell)
                        .offset(x: origin(i % Game.size), y: origin(i / Game.size))
                }

                ForEach(store.displayTiles) { tile in
                    TileView(tile: tile, size: cell, radius: side * 0.018)
                        .offset(x: origin(tile.col), y: origin(tile.row))
                        .zIndex(store.ghosts.contains(tile) ? 0 : (tile.isMerged ? 2 : 1))
                        .transition(appear)
                }

                GameOverlay(radius: radius, side: side)
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("2048 棋盘")
        .accessibilityValue(accessibilitySummary)
    }

    private var appear: AnyTransition {
        reduceMotion
            ? AnyTransition.identity
            : AnyTransition.scale(scale: 0).combined(with: .opacity)
                .animation(.easeOut(duration: 0.18).delay(0.09))
    }

    private var accessibilitySummary: String {
        let rows = (0..<Game.size).map { r in
            (0..<Game.size).map { c in
                store.game.tiles.first { $0.row == r && $0.col == c }.map { String($0.value) } ?? "空"
            }.joined(separator: "，")
        }
        return rows.enumerated().map { "第\($0.offset + 1)行：\($0.element)" }.joined(separator: "；")
    }
}

struct TileView: View {
    let tile: Tile
    let size: CGFloat
    let radius: CGFloat
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let colors = palette.tile(tile.value)
        let glow = tile.value >= 128
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(colors.background
                .shadow(.inner(color: .black.opacity(glow ? 0.14 : 0.12), radius: 0, y: -size * 0.033))
                .shadow(.inner(color: .white.opacity(glow ? 0.28 : 0.22), radius: 0, y: size * 0.023)))
            .shadow(color: glow ? colors.background.opacity(0.7) : .clear, radius: size * 0.12)
            .overlay {
                Text(String(tile.value))
                    .font(.display(size * fontScale, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(colors.foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, size * 0.06)
            }
            .frame(width: size, height: size)
            .keyframeAnimator(initialValue: 1.0, trigger: tile.value) { content, scale in
                content.scaleEffect(scale)
            } keyframes: { _ in
                CubicKeyframe(tile.isMerged && !reduceMotion ? 1.16 : 1.0, duration: 0.08)
                CubicKeyframe(1.0, duration: 0.1)
            }
    }

    private var fontScale: CGFloat {
        switch String(tile.value).count {
        case ...2: 0.47
        case 3: 0.38
        case 4: 0.3
        default: 0.24
        }
    }
}

struct GameOverlay: View {
    let radius: CGFloat
    let side: CGFloat
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let game = store.game
        Group {
            if game.isWonPause {
                panel(title: "拼出 2048！", message: "得分 \(game.score)。可以继续挑战 4096。") {
                    Button("继续玩") { store.keepGoing() }
                        .buttonStyle(PillButtonStyle(primary: true))
                    Button("新游戏") { store.newGame() }
                        .buttonStyle(PillButtonStyle())
                }
            } else if game.isOver {
                panel(title: "没有可走的步了", message: "本局得分 \(game.score)") {
                    Button("撤销一步") { store.undo(animated: !reduceMotion) }
                        .buttonStyle(PillButtonStyle())
                        .disabled(!game.canUndo)
                    Button("再来一局") { store.newGame() }
                        .buttonStyle(PillButtonStyle(primary: true))
                }
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.4), value: game.isWonPause || game.isOver)
    }

    private func panel(title: String, message: String, @ViewBuilder buttons: () -> some View) -> some View {
        VStack(spacing: side * 0.04) {
            Text(title)
                .font(.display(side * 0.1))
                .multilineTextAlignment(.center)
                .foregroundStyle(palette.foreground)
            Text(message)
                .font(.system(size: max(14, side * 0.036)))
                .foregroundStyle(palette.muted)
                .multilineTextAlignment(.center)
            HStack(spacing: 8) { buttons() }
        }
        .padding()
        .frame(width: side, height: side)
        .background(palette.overlay, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .transition(.opacity)
    }
}
