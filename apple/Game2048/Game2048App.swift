import SwiftUI

@main
struct Game2048App: App {
    @State private var store = GameStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
        #if os(macOS)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 520, height: 780)
        #endif
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新游戏") { store.newGame() }
                    .keyboardShortcut("n")
            }
            CommandGroup(replacing: .undoRedo) {
                Button("撤销") { store.undo(animated: true) }
                    .keyboardShortcut("z")
                    .disabled(!store.game.canUndo)
            }
        }
    }
}
