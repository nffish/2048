import XCTest
@testable import Game2048Core

/// Deterministic generator so spawns are reproducible.
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

final class GameTests: XCTestCase {
    var rng = SplitMix64(state: 42)

    /// Builds a game from rows of values, 0 meaning empty.
    func game(_ rows: [[Int]], score: Int = 0) -> Game {
        var tiles: [Tile] = []
        var id = 1
        for (r, row) in rows.enumerated() {
            for (c, v) in row.enumerated() where v != 0 {
                tiles.append(Tile(id: id, value: v, row: r, col: c))
                id += 1
            }
        }
        return Game(state: GameState(tiles: tiles, score: score, nextID: id))
    }

    /// Values on the board after a move, ignoring the freshly spawned tile.
    func grid(_ game: Game) -> [[Int]] {
        var g = [[Int]](repeating: [0, 0, 0, 0], count: 4)
        for t in game.tiles where !t.isNew { g[t.row][t.col] = t.value }
        return g
    }

    func testStartSpawnsTwoTiles() {
        let g = Game.start(using: &rng)
        XCTAssertEqual(g.tiles.count, 2)
        XCTAssertTrue(g.tiles.allSatisfy { $0.value == 2 || $0.value == 4 })
        XCTAssertNotEqual(g.tiles[0].row * 4 + g.tiles[0].col, g.tiles[1].row * 4 + g.tiles[1].col)
    }

    func testSlideLeftMergesOncePerPair() {
        var g = game([[2, 2, 2, 2], [4, 0, 4, 8], [2, 4, 8, 16], [0, 0, 0, 2]])
        let outcome = g.move(.left, using: &rng)
        XCTAssertEqual(grid(g), [[4, 4, 0, 0], [8, 8, 0, 0], [2, 4, 8, 16], [2, 0, 0, 0]])
        XCTAssertEqual(outcome?.gained, 4 + 4 + 8)
        XCTAssertEqual(g.score, 16)
        XCTAssertEqual(outcome?.consumed.count, 3)
        XCTAssertEqual(g.tiles.filter(\.isNew).count, 1)
    }

    func testMergedTileDoesNotMergeAgain() {
        var g = game([[4, 2, 2, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        g.move(.left, using: &rng)
        XCTAssertEqual(grid(g)[0], [4, 4, 0, 0])
    }

    func testOtherDirections() {
        var right = game([[2, 2, 4, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        right.move(.right, using: &rng)
        XCTAssertEqual(grid(right)[0], [0, 0, 4, 4])

        var up = game([[2, 0, 0, 0], [0, 0, 0, 0], [2, 0, 0, 0], [4, 0, 0, 0]])
        up.move(.up, using: &rng)
        XCTAssertEqual(grid(up).map { $0[0] }, [4, 4, 0, 0])

        var down = game([[2, 0, 0, 0], [2, 0, 0, 0], [2, 0, 0, 0], [0, 0, 0, 0]])
        down.move(.down, using: &rng)
        XCTAssertEqual(grid(down).map { $0[0] }, [0, 0, 2, 4])
    }

    func testConsumedTileSitsOnItsPartner() throws {
        var g = game([[0, 2, 0, 2], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        let outcome = g.move(.left, using: &rng)
        let ghost = try XCTUnwrap(outcome?.consumed.first)
        let survivor = try XCTUnwrap(g.tiles.first { $0.isMerged })
        XCTAssertEqual(ghost.row, survivor.row)
        XCTAssertEqual(ghost.col, survivor.col)
        XCTAssertEqual(survivor.col, 0)
        XCTAssertNotEqual(ghost.id, survivor.id)
    }

    func testNoMoveNoSpawnNoUndoStep() {
        var g = game([[2, 4, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        XCTAssertNil(g.move(.left, using: &rng))
        XCTAssertEqual(g.tiles.count, 2)
        XCTAssertFalse(g.canUndo)
    }

    func testUndoRestoresPreviousState() {
        var g = game([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]], score: 10)
        let before = g.state
        g.move(.right, using: &rng)
        XCTAssertTrue(g.canUndo)
        g.undo()
        XCTAssertEqual(g.state, before)
        XCTAssertFalse(g.canUndo)
    }

    func testGameOverDetection() {
        let stuck = game([[2, 4, 2, 4], [4, 2, 4, 2], [2, 4, 2, 4], [4, 2, 4, 2]])
        XCTAssertTrue(stuck.isOver)
        var copy = stuck
        XCTAssertNil(copy.move(.left, using: &rng))

        let mergeable = game([[2, 4, 2, 4], [4, 2, 4, 2], [2, 4, 2, 4], [4, 2, 4, 4]])
        XCTAssertFalse(mergeable.isOver)
    }

    func testReaching2048PausesUntilKeepGoing() {
        var g = game([[1024, 1024, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
        g.move(.left, using: &rng)
        XCTAssertTrue(g.isWonPause)
        XCTAssertNil(g.move(.right, using: &rng))
        g.keepGoing()
        XCTAssertFalse(g.isWonPause)
        XCTAssertNotNil(g.move(.right, using: &rng))
        XCTAssertFalse(g.isWonPause)
    }

    func testSpawnsAreTwosOrFoursAtRoughlyNineToOne() {
        var fours = 0
        for _ in 0..<2000 {
            var g = Game()
            g.spawn(using: &rng)
            if g.tiles[0].value == 4 { fours += 1 }
        }
        XCTAssertTrue((120...280).contains(fours), "got \(fours) fours")
    }

    func testCodableRoundTrip() throws {
        var g = Game.start(using: &rng)
        g.move(.left, using: &rng)
        g.move(.up, using: &rng)
        let data = try JSONEncoder().encode(g)
        XCTAssertEqual(try JSONDecoder().decode(Game.self, from: data), g)
    }
}
