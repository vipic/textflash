# TextFlash 发布流程

本文档记录本项目当前的本地发布流程。项目目前没有开发者账号签名和公证，因此产物是自签名应用，不做 notarization。

## 前置条件

- macOS 13+
- Xcode Command Line Tools
- `gh` CLI：仅 `--publish` 发布 GitHub Release 时需要
- 固定代码签名证书：默认使用作者级证书 `Nekutai`，也可通过 `CODESIGN_IDENTITY` 指定自己的自签名或开发者账号证书名

创建证书（已有同名作者证书可直接复用，多个应用可以共用同一张代码签名证书）：

```text
Keychain Access -> 证书助理 -> 创建证书
名称: Nekutai
身份类型: 自签名根
证书类型: 代码签名
```

如果证书名不是 `Nekutai`，通过环境变量覆盖：

```bash
export CODESIGN_IDENTITY="Nekutai"
```

TextFlash 需要辅助功能授权，必须使用稳定代码身份。没有匹配证书或签名失败时脚本会直接停止；显式设置 `CODESIGN_IDENTITY="-"` 也会被拒绝。不要使用 ad-hoc 签名，因为每次构建都可能破坏辅助功能授权，导致用户反复重新授权。

## 版本号规则

发布命令传裸版本号：

```bash
./release.sh 0.1.12
```

脚本内部会自动生成 Git tag `v0.1.12`。如果传入 `v0.1.12`，脚本也会先剥掉前缀 `v`，避免应用内更新检查出现 `vv0.1.12`。

## 本地构建 DMG

```bash
./release.sh 0.1.12
```

脚本会执行：

- `mise run check`（脚本、设计 token、测试和 release build）
- 注入 `AppVersion`
- release 编译
- 去除调试符号
- 组装 `.app`
- 固定作者级证书签名
- 使用品牌背景打包 DMG，并在最终可写镜像上由 Finder 现场生成图标布局
- `hdiutil verify` 与 SHA-256 校验文件
- 从 DMG 复制并首次启动正式 bundle，验证签名、版本、菜单栏激活策略和图标

产物在：

```text
dist/TextFlash-0.1.12.dmg
```

### DMG 背景生成提示词

背景使用 Codex 内置 ImageGen 生成；生成结果居中裁切后保存为 `Resources/dmg-background@2x.png`（1080×700），再缩放生成 `Resources/dmg-background.png`（540×350）。重建时使用以下提示词：

```text
Use case: ads-marketing
Asset type: Retina macOS DMG installer background for TextFlash
Primary request: Create a polished 1080×700 landscape installer background that guides dragging the TextFlash app from the left to Applications on the right.
Scene/backdrop: very pale lavender-white surface with a subtle clean text-editor grid and faint flowing text-line rhythm.
Style/medium: restrained premium native macOS utility aesthetic, clean flat illustration with very soft depth.
Composition/framing: exactly two equal-size large rounded-square recessed wells, one centered around x=280 and one centered around x=800, both centered vertically around y=375; a thin muted lavender-gray arrow points from the left well to the right well. Leave both wells empty for Finder icons. Keep generous clean margins and uncluttered space.
Color palette: warm white, pale lavender, muted indigo, one tiny soft peach accent.
Brand motif: a very faint abstract transformation motif near the lower center—short text-like horizontal strokes flowing through a subtle lightning-shaped cursor into longer strokes—purely abstract, no readable characters.
Constraints: no words, no letters, no labels, no app icons, no folder icons, no logos, no screenshots, no watermark signature. Do not place any object inside the two icon wells. Exact landscape aspect ratio 1080:700.
```

## 发布到 GitHub Releases

```bash
./release.sh 0.1.12 --publish
```

发布模式要求：

- 当前分支是 `main`
- 工作区干净
- 当前 commit 没有不匹配的 tag
- `gh auth status` 可用

脚本会创建 annotated tag `v0.1.12`，原子推送 `main` 与 tag，再创建 GitHub Release。已有同名 tag 或 Release 时直接停止，不覆盖资产；Release 创建失败时回滚本轮 tag。DMG 和同名 `.sha256` 会一起上传。

## 发布耗时与本地日志

每次本地 release/publish 的阶段耗时、退出码和完整命令输出保存在 `.local/logs/`。查看摘要或完整日志：

```bash
mise run logs:release
mise run logs:release -- --full
mise run logs:publish
```

## GitHub Actions 构建验证

仓库里有两个 workflow：

- `CI`：`main` 分支 push 和 pull request 自动触发，执行脚本语法检查、`swift test` 和 release build。
- `Release Build Verification`：只支持手动触发，执行 `mise run check`。

手动验证 release build：

1. 打开 GitHub 仓库的 **Actions**
2. 选择 **Release Build Verification**
3. 点击 **Run workflow**

CI 不导入或保存 `Nekutai` 私钥，因此不会组装、签名或上传正式 DMG。正式制品只在持有稳定证书的受控 Mac 上通过本地 `release.sh` 生成。

## 没有开发者账号时的限制

当前发布产物没有 notarization。用户首次打开时可能遇到 Gatekeeper 提示，需要在系统设置中允许打开。

这不是脚本错误，而是 Apple 对非公证应用的限制。拿到开发者账号后，后续应补充：

- 开发者账号签名
- 公证上传
- stapler 固定票据
- CI 发布链路中的公证校验

## 自动更新失败日志

应用内自动更新会生成 helper 脚本并替换 `.app`。如果安装失败，日志写入：

```text
/tmp/textflash_update.log
```

如果是 Bundle ID、版本号、签名或安装校验失败，helper 还会写入面向用户的错误原因：

```text
/tmp/textflash_update_error.txt
```

旧 App 被重新打开后会读取错误文件并显示更新失败窗口。排查时优先查看 `textflash_update.log`，需要确认用户看到的错误文案时再查看 `textflash_update_error.txt`。安装脚本会先备份旧版本，再复制新版本；复制失败时会恢复旧 App。

## 发布前检查清单

```bash
git status --short
mise run check
./release.sh 0.1.12
```

确认 DMG 可以挂载，拖入 `/Applications` 后应用可启动，再执行 `--publish`。
