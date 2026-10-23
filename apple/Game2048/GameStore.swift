import SwiftUI

/// Owns the current game, the best score and the short-lived visuals of a move; saves after every change.
@MainActor
@Observable
final class GameStore {
    struct Gain: Equatable {
        let id: Int
        let amount: Int
    }

    private(set) var game: Game
    private(set) var best: Int
    /// Tiles swallowed by the last merge; drawn under their partner until the slide finishes.
    private(set) var ghosts: [Tile] = []
    private(set) var lastGain: Gain?
    /// Bumps on every successful move, for haptics.
    private(set) var moveCount = 0

    @ObservationIgnored private var rng = SystemRandomNumberGenerator()
    @ObservationIgnored private var ghostTask: Task<Void, Never>?
    @ObservationIgnored private let defaults: UserDefaults

    static let slide = 0.11

    private static let gameKey = "g2048.game"
    private static let bestKey = "g2048.best"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        best = defaults.integer(forKey: Self.bestKey)
        if let data = defaults.data(forKey: Self.gameKey),
           let saved = try? JSONDecoder().decode(Game.self, from: data) {
            game = saved
        } else {
            var rng = SystemRandomNumberGenerator()
            game = Game.start(using: &rng)
        }
    }

    var displayTiles: [Tile] { ghosts + game.tiles }

    func move(_ direction: Direction, animated: Bool) {
        clearGhosts()
        var next = game
        guard let outcome = next.move(direction, using: &rng) else { return }

        withAnimation(animated ? .easeInOut(duration: Self.slide) : nil) {
            ghosts = outcome.consumed
            game = next
        }
        moveCount += 1
        if outcome.gained > 0 {
            lastGain = Gain(id: (lastGain?.id ?? 0) + 1, amount: outcome.gained)
        }
        if !outcome.consumed.isEmpty {
            ghostTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(Self.slide))
                guard !Task.isCancelled else { return }
                self?.ghosts = []
            }
        }
        save()
    }

    func undo(animated: Bool) {
        guard game.canUndo else { return }
        clearGhosts()
        withAnimation(animated ? .easeInOut(duration: Self.slide) : nil) {
            game.undo()
        }
        save()
    }

    func newGame() {
        clearGhosts()
        lastGain = nil
        game = Game.start(using: &rng)
        save()
    }

    func keepGoing() {
        game.keepGoing()
        save()
    }

    private func clearGhosts() {
        ghostTask?.cancel()
        ghostTask = nil
        ghosts = []
    }

    private func save() {
        if game.score > best {
            best = game.score
            defaults.set(best, forKey: Self.bestKey)
        }
        if let data = try? JSONEncoder().encode(game) {
            defaults.set(data, forKey: Self.gameKey)
        }
    }
}
