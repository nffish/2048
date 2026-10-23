import Foundation

// Pure game rules, shared by the app and the Swift package tests. No UI code here.

enum Direction: CaseIterable {
    case up, down, left, right
}

struct Tile: Identifiable, Hashable, Codable {
    let id: Int
    var value: Int
    var row: Int
    var col: Int
    var isNew = false
    var isMerged = false
}

struct GameState: Equatable, Codable {
    var tiles: [Tile] = []
    var score = 0
    var won = false
    var keepGoing = false
    var nextID = 1
}

struct MoveOutcome: Equatable {
    /// Points earned by this move's merges.
    var gained: Int
    /// Tiles swallowed by a merge, placed on the cell they merged into, so the UI can slide them there before removing them.
    var consumed: [Tile]
}

struct Game: Codable, Equatable {
    static let size = 4
    static let winValue = 2048

    private(set) var state = GameState()
    /// The state before the last move, for a single-step undo.
    private(set) var previous: GameState?

    var tiles: [Tile] { state.tiles }
    var score: Int { state.score }
    var canUndo: Bool { previous != nil }
    var maxTile: Int { max(state.tiles.map(\.value).max() ?? 0, 2) }

    /// Waiting on the player to choose "keep going" after reaching 2048.
    var isWonPause: Bool { state.won && !state.keepGoing }
    var isOver: Bool { !Self.canMove(state.tiles) }

    init() {}

    init(state: GameState, previous: GameState? = nil) {
        self.state = state
        self.previous = previous
    }

    static func start(using rng: inout some RandomNumberGenerator) -> Game {
        var game = Game()
        game.spawn(using: &rng)
        game.spawn(using: &rng)
        return game
    }

    mutating func keepGoing() {
        state.keepGoing = true
    }

    mutating func undo() {
        guard let previous else { return }
        state = previous
        for i in state.tiles.indices {
            state.tiles[i].isNew = false
            state.tiles[i].isMerged = false
        }
        self.previous = nil
    }

    /// Slides every tile toward `direction`, merging equal neighbours once per move, then spawns a tile.
    /// Returns nil when nothing moved, so no tile spawns and the undo step is kept.
    @discardableResult
    mutating func move(_ direction: Direction, using rng: inout some RandomNumberGenerator) -> MoveOutcome? {
        guard !isOver, !isWonPause else { return nil }

        let n = Self.size
        var byCell: [Int: Tile] = [:]
        for tile in state.tiles { byCell[tile.row * n + tile.col] = tile }

        var result: [Tile] = []
        var consumed: [Tile] = []
        var moved = false
        var gained = 0

        for line in Self.lines(direction) {
            var out: [Tile] = []
            for cell in line {
                guard var tile = byCell[cell.row * n + cell.col] else { continue }
                tile.isNew = false
                tile.isMerged = false
                if let last = out.last, !last.isMerged, last.value == tile.value {
                    let k = out.count - 1
                    out[k].value *= 2
                    out[k].isMerged = true
                    gained += out[k].value
                    tile.row = line[k].row
                    tile.col = line[k].col
                    consumed.append(tile)
                    moved = true
                } else {
                    out.append(tile)
                }
            }
            for (k, var tile) in out.enumerated() {
                if tile.row != line[k].row || tile.col != line[k].col { moved = true }
                tile.row = line[k].row
                tile.col = line[k].col
                result.append(tile)
            }
        }

        guard moved else { return nil }

        previous = state
        state.tiles = result
        state.score += gained
        spawn(using: &rng)
        if !state.won, state.tiles.contains(where: { $0.value >= Self.winValue }) {
            state.won = true
        }
        return MoveOutcome(gained: gained, consumed: consumed)
    }

    mutating func spawn(using rng: inout some RandomNumberGenerator) {
        let n = Self.size
        let taken = Set(state.tiles.map { $0.row * n + $0.col })
        let empty = (0..<(n * n)).filter { !taken.contains($0) }
        guard let cell = empty.randomElement(using: &rng) else { return }
        let value = Double.random(in: 0..<1, using: &rng) < 0.9 ? 2 : 4
        state.tiles.append(Tile(id: state.nextID, value: value, row: cell / n, col: cell % n, isNew: true))
        state.nextID += 1
    }

    static func canMove(_ tiles: [Tile]) -> Bool {
        let n = size
        if tiles.count < n * n { return true }
        var grid = [[Int]](repeating: [Int](repeating: 0, count: n), count: n)
        for tile in tiles { grid[tile.row][tile.col] = tile.value }
        for r in 0..<n {
            for c in 0..<n {
                if c + 1 < n, grid[r][c] == grid[r][c + 1] { return true }
                if r + 1 < n, grid[r][c] == grid[r + 1][c] { return true }
            }
        }
        return false
    }

    /// Cells of each row or column, ordered from the edge tiles slide toward.
    static func lines(_ direction: Direction) -> [[(row: Int, col: Int)]] {
        let n = size
        return (0..<n).map { a in
            (0..<n).map { b -> (row: Int, col: Int) in
                switch direction {
                case .left: (a, b)
                case .right: (a, n - 1 - b)
                case .up: (b, a)
                case .down: (n - 1 - b, a)
                }
            }
        }
    }
}
