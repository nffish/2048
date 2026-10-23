# 2048 釉面版 · iOS / iPadOS / macOS

A native SwiftUI port of the web game in `../index.html`. One target builds for iPhone, iPad and Mac.

- `Game2048/Model/Game.swift`: game rules only (no UI), also built by `Package.swift` for unit tests.
- `Game2048/GameStore.swift`: current game, best score, saving to `UserDefaults`.
- `Game2048/Views/`: board, tiles, scores, overlays and the colour palette.
- Requirements: Xcode 16 or newer, iOS 17 / macOS 14 or newer.

## 在 Mac 上运行

1. 打开 `apple/Game2048.xcodeproj`。
2. 选中左侧的 Game2048 项目 → TARGETS 里的 Game2048 → Signing & Capabilities，在 Team 里选你的 Apple 账号。
3. 顶部的运行目标选一个 iPhone 模拟器，或者「My Mac」，按 ⌘R。

运行单元测试：在 `apple/` 目录执行 `swift test`。

## 上架 App Store

1. 加入 Apple Developer Program（个人 99 美元/年）：<https://developer.apple.com/programs/enroll/>
2. Bundle ID 现在是 `io.github.nffish.game2048`，可以在 Signing & Capabilities 里改成你自己的。
3. 在 App Store Connect（<https://appstoreconnect.apple.com>）→「我的 App」→「+」→ 新建 App，平台勾选 iOS 和 macOS，选上面的 Bundle ID。名称不能和已有应用重名，「2048」肯定被占用了，可以用「2048 釉面版」之类。
4. 在 Xcode 里把运行目标选成「Any iOS Device」，菜单 Product → Archive，完成后在 Organizer 里点 Distribute App → App Store Connect 上传。macOS 版把目标换成「Any Mac」再归档一次。
5. 回到 App Store Connect 填写：截图（iPhone 6.9 寸、iPad 13 寸、Mac 各至少一张）、描述、关键词、支持网址（可以用 https://nffish.github.io/2048/ ）、隐私政策网址（已准备好：https://nffish.github.io/2048/privacy.html ，合并后生效）、年龄分级。
6. 隐私问卷选「不收集任何数据」：游戏只把进度和最高分存在本机。
7. 选择上传的构建版本，提交审核。
